from flask import Flask, render_template, jsonify, request, session, redirect, url_for
import os
import logging
from functools import wraps
import base64
from datetime import datetime, timedelta
from database import init_db, save_clipboard_entry, get_clipboard_entry, get_clipboard_history, get_clipboard_version, wait_for_clipboard_change, authenticate_user, create_user
from PIL import Image
import io
from version import get_cached_version, get_numeric_version

app = Flask(__name__)

app.secret_key = os.environ.get('SECRET_KEY', 'your-secret-key-change-this-in-production')

# Configure session to be permanent and last forever
app.permanent_session_lifetime = timedelta(days=365 * 10)  # 10 years

# Setup logging that works with Gunicorn
if __name__ != '__main__':
    # When running under Gunicorn, use Gunicorn's logger
    gunicorn_logger = logging.getLogger('gunicorn.error')
    app.logger.handlers = gunicorn_logger.handlers
    app.logger.setLevel(gunicorn_logger.level)
    logger = app.logger
else:
    # When running directly, use basic config
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger(__name__)

# Get and log application version
app_version = get_cached_version()
numeric_version = get_numeric_version(app_version)

# Log version using print for immediate visibility and logger for proper logging
print(f"🚀 CopyPasta v{numeric_version} - Flask app initialized")
logger.info(f"🚀 CopyPasta v{numeric_version} starting up...")

# Initialize database on startup
init_db()
logger.info("📋 Database initialized successfully")

def login_required(f):
    """Decorator to require authentication for routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('user_id'):
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function


@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        user_id = authenticate_user(username, password)
        if user_id:
            session.permanent = True
            session['user_id'] = user_id
            session['username'] = username
            next_page = request.args.get('next')
            return redirect(next_page) if next_page else redirect(url_for('index'))
        else:
            return render_template('login.html', error='Invalid username or password')
    
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    """Registration page"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        confirm_password = request.form.get('confirm_password')
        
        if not username or not password:
            return render_template('register.html', error='Username and password are required')
        
        if password != confirm_password:
            return render_template('register.html', error='Passwords do not match')
        
        if len(password) < 4:
            return render_template('register.html', error='Password must be at least 4 characters long')
        
        try:
            user_id = create_user(username, password)
            session.permanent = True
            session['user_id'] = user_id
            session['username'] = username
            return redirect(url_for('index'))
        except ValueError as e:
            return render_template('register.html', error=str(e))
    
    return render_template('register.html')

@app.route('/logout')
def logout():
    """Logout and clear session"""
    session.pop('user_id', None)
    session.pop('username', None)
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    """Main page"""
    return render_template('index.html', 
                         version=numeric_version,
                         full_version=app_version)

@app.route('/api/paste', methods=['POST'])
@login_required
def paste():
    """Save content to clipboard"""
    try:
        data = request.get_json()
        content_type = data.get('type', 'text')
        content = data.get('content', '')
        client_id = data.get('client_id', None)
        
        if not content:
            return jsonify({'error': 'No content provided'}), 400
        
        # Handle different content types
        if content_type == 'image':
            # Validate base64 image data
            try:
                if content.startswith('data:image/'):
                    header, base64_data = content.split(',', 1)
                else:
                    base64_data = content
                
                # Try to decode and validate the image
                image_data = base64.b64decode(base64_data)
                img = Image.open(io.BytesIO(image_data))
                img.verify()  # Verify it's a valid image
                
            except Exception as e:
                return jsonify({'error': 'Invalid image data'}), 400
        
        elif content_type == 'rich':
            # Validate and sanitize rich text content
            # For now, we'll allow HTML content but could add sanitization here
            if not content or len(content.strip()) == 0:
                return jsonify({'error': 'Rich content cannot be empty'}), 400
            
            # Basic validation - ensure it's not too large
            if len(content) > 10000000:  # 10MB limit for rich content
                return jsonify({'error': 'Rich content too large (max 10MB)'}), 400
        
        # Save to database
        metadata = {
            'timestamp': datetime.utcnow().isoformat() + 'Z',
            'user_agent': request.headers.get('User-Agent', '')
        }
        
        user_id = session.get('user_id')
        save_clipboard_entry(user_id, content_type, content, str(metadata), client_id)
        
        return jsonify({
            'status': 'success',
            'message': 'Content saved to clipboard',
            'timestamp': datetime.utcnow().isoformat() + 'Z'
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/clipboard')
@login_required
def get_clipboard():
    """Get current clipboard content"""
    try:
        user_id = session.get('user_id')
        entry = get_clipboard_entry(user_id)
        if entry:
            return jsonify({
                'status': 'success',
                'data': entry
            })
        else:
            return jsonify({
                'status': 'success',
                'data': None,
                'message': 'No clipboard content found'
            })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/clipboard/history')
@login_required
def get_clipboard_history_api():
    """Get clipboard history for the current user"""
    try:
        user_id = session.get('user_id')
        limit = request.args.get('limit', 10, type=int)
        limit = max(1, min(limit, 50))  # Limit between 1 and 50
        
        history = get_clipboard_history(user_id, limit)
        return jsonify({
            'status': 'success',
            'data': history
        })
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/data')
@login_required
def api_data():
    """Sample API endpoint for backward compatibility"""
    return jsonify({
        'message': 'CopyPasta API is running!',
        'status': 'success'
    })

@app.route('/api/poll')
@login_required  
def poll_clipboard():
    """Long polling endpoint for clipboard changes"""
    try:
        # Get the last known version from query parameter
        last_version = request.args.get('version', 0, type=int)
        timeout = request.args.get('timeout', 30, type=int)
        client_id = request.args.get('client_id', None)
        
        # Limit timeout to reasonable range
        timeout = max(1, min(timeout, 60))
        
        # Helper function to check if entry should be sent to this client
        def should_send_to_client(entry):
            if not entry or not client_id:
                return True  # Send if no filtering needed
            return entry.get('client_id') != client_id  # Don't send if same client
        
        user_id = session.get('user_id')
        
        # Check if there's already a change
        current_version = get_clipboard_version(user_id)
        if current_version > last_version:
            entry = get_clipboard_entry(user_id)
            if should_send_to_client(entry):
                return jsonify({
                    'status': 'success',
                    'data': entry,
                    'version': current_version
                })
        
        # Wait for change
        entry = wait_for_clipboard_change(user_id, last_version, timeout)
        
        # Always get the latest version for consistent responses
        final_version = get_clipboard_version(user_id)
        
        if entry and should_send_to_client(entry):
            return jsonify({
                'status': 'success',
                'data': entry,
                'version': final_version
            })
        else:
            # Timeout or filtered out - return current state
            return jsonify({
                'status': 'timeout',
                'version': final_version,
                'message': 'No changes within timeout period'
            })
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'version': numeric_version,
        'app_name': 'CopyPasta'
    })

@app.route('/api/version')
def api_version():
    """Version information endpoint"""
    return jsonify({
        'version': numeric_version,
        'full_version': app_version,
        'app_name': 'CopyPasta',
        'status': 'success'
    })

if __name__ == '__main__':
    # For development only - use gunicorn in production
    app.run(host='0.0.0.0', port=5000, debug=False)
