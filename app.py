from flask import Flask, render_template, jsonify, request, session, redirect, url_for
import os
from functools import wraps
import base64
from datetime import datetime, timedelta
from database import init_db, save_clipboard_entry, get_clipboard_entry, get_clipboard_version, wait_for_clipboard_change
from PIL import Image
import io

app = Flask(__name__)

# Get authentication credentials from environment variables
USERNAME = os.environ.get('APP_USERNAME', 'user')
PASSWORD = os.environ.get('APP_PASSWORD', 'password')
app.secret_key = os.environ.get('SECRET_KEY', 'your-secret-key-change-this-in-production')

# Configure session to be permanent and last forever
app.permanent_session_lifetime = timedelta(days=365 * 10)  # 10 years

# Initialize database on startup
init_db()

def login_required(f):
    """Decorator to require authentication for routes"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if not session.get('authenticated'):
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function


@app.route('/login', methods=['GET', 'POST'])
def login():
    """Login page"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        if username == USERNAME and password == PASSWORD:
            session.permanent = True
            session['authenticated'] = True
            next_page = request.args.get('next')
            return redirect(next_page) if next_page else redirect(url_for('index'))
        else:
            return render_template('login.html', error='Invalid username or password')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """Logout and clear session"""
    session.pop('authenticated', None)
    return redirect(url_for('login'))

@app.route('/')
@login_required
def index():
    """Main page"""
    return render_template('index.html')

@app.route('/api/paste', methods=['POST'])
@login_required
def paste():
    """Save content to clipboard"""
    try:
        data = request.get_json()
        content_type = data.get('type', 'text')
        content = data.get('content', '')
        
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
            'timestamp': datetime.now().isoformat(),
            'user_agent': request.headers.get('User-Agent', '')
        }
        
        save_clipboard_entry(content_type, content, str(metadata))
        
        return jsonify({
            'status': 'success',
            'message': 'Content saved to clipboard',
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/clipboard')
@login_required
def get_clipboard():
    """Get current clipboard content"""
    try:
        entry = get_clipboard_entry()
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
        
        # Limit timeout to reasonable range
        timeout = max(1, min(timeout, 60))
        
        # Check if there's already a change
        current_version = get_clipboard_version()
        if current_version > last_version:
            entry = get_clipboard_entry()
            return jsonify({
                'status': 'success',
                'data': entry,
                'version': current_version
            })
        
        # Wait for change
        entry = wait_for_clipboard_change(last_version, timeout)
        
        if entry:
            return jsonify({
                'status': 'success',
                'data': entry,
                'version': entry.get('version', current_version)
            })
        else:
            # Timeout - return current state
            return jsonify({
                'status': 'timeout',
                'version': current_version,
                'message': 'No changes within timeout period'
            })
            
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    # For development only - use gunicorn in production
    app.run(host='0.0.0.0', port=5000, debug=False)
