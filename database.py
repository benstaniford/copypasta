import sqlite3
import os
from datetime import datetime
import base64
import threading
import time
import hashlib
import secrets

DATABASE_PATH = os.path.join(os.path.dirname(__file__), 'clipboard.db')

# Global lock and condition for clipboard change notifications
_clipboard_lock = threading.Lock()
_clipboard_changed_condition = threading.Condition(_clipboard_lock)

def init_db():
    """Initialize the database with required tables"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    
    # Create users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS clipboard_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            content_type TEXT NOT NULL,
            content TEXT NOT NULL,
            metadata TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            version INTEGER DEFAULT 1,
            client_id TEXT,
            filename TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # Create metadata table for per-user version counters
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS user_metadata (
            user_id INTEGER NOT NULL,
            key TEXT NOT NULL,
            value INTEGER NOT NULL,
            PRIMARY KEY (user_id, key),
            FOREIGN KEY (user_id) REFERENCES users (id)
        )
    ''')
    
    # Migration: Add user_id column if it doesn't exist
    try:
        cursor.execute('ALTER TABLE clipboard_entries ADD COLUMN user_id INTEGER')
    except sqlite3.OperationalError:
        pass  # Column already exists

    # Migration: Add new columns if they don't exist
    try:
        cursor.execute('ALTER TABLE clipboard_entries ADD COLUMN version INTEGER DEFAULT 1')
    except sqlite3.OperationalError:
        pass  # Column already exists

    try:
        cursor.execute('ALTER TABLE clipboard_entries ADD COLUMN client_id TEXT')
    except sqlite3.OperationalError:
        pass  # Column already exists

    try:
        cursor.execute('ALTER TABLE clipboard_entries ADD COLUMN filename TEXT')
    except sqlite3.OperationalError:
        pass  # Column already exists
    
    # Create default user from environment variables if it doesn't exist
    default_username = os.environ.get('APP_USERNAME', 'user')
    default_password = os.environ.get('APP_PASSWORD', 'password')
    create_user_if_not_exists(default_username, default_password)
    
    conn.commit()
    conn.close()

def clear_clipboard(user_id):
    """Remove all existing clipboard entries for a user"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    cursor.execute('DELETE FROM clipboard_entries WHERE user_id = ?', (user_id,))
    conn.commit()
    conn.close()

def save_clipboard_entry(user_id, content_type, content, metadata=None, client_id=None, filename=None):
    """Save a new clipboard entry for a user, maintaining history with FIFO deletion (max 10 entries)
    If the content already exists in history, reorder it to be the most recent instead of creating a duplicate"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()

    try:
        # Start transaction for atomic operation
        cursor.execute('BEGIN IMMEDIATE')

        # Check if this exact content already exists for this user
        cursor.execute('''
            SELECT id, created_at FROM clipboard_entries
            WHERE user_id = ? AND content_type = ? AND content = ?
            ORDER BY created_at DESC
            LIMIT 1
        ''', (user_id, content_type, content))

        existing_entry = cursor.fetchone()

        # Increment version counter for this user
        cursor.execute('''
            INSERT OR REPLACE INTO user_metadata (user_id, key, value)
            VALUES (?, "clipboard_version", COALESCE((SELECT value FROM user_metadata WHERE user_id = ? AND key = "clipboard_version"), 0) + 1)
        ''', (user_id, user_id))

        # Get the new version
        cursor.execute('SELECT value FROM user_metadata WHERE user_id = ? AND key = "clipboard_version"', (user_id,))
        version = cursor.fetchone()[0]

        if existing_entry:
            # Update existing entry to make it the most recent
            entry_id = existing_entry[0]
            cursor.execute('''
                UPDATE clipboard_entries
                SET created_at = ?, version = ?, metadata = ?, client_id = ?, filename = ?
                WHERE id = ?
            ''', (datetime.now().isoformat(), version, metadata, client_id, filename, entry_id))
        else:
            # Insert new clipboard entry
            cursor.execute('''
                INSERT INTO clipboard_entries (user_id, content_type, content, metadata, created_at, version, client_id, filename)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            ''', (user_id, content_type, content, metadata, datetime.now().isoformat(), version, client_id, filename))

        # Maintain FIFO history - keep only the 10 most recent entries per user
        cursor.execute('''
            DELETE FROM clipboard_entries
            WHERE user_id = ?
            AND id NOT IN (
                SELECT id FROM clipboard_entries
                WHERE user_id = ?
                ORDER BY created_at DESC
                LIMIT 10
            )
        ''', (user_id, user_id))

        # Commit transaction
        conn.commit()

    except Exception as e:
        conn.rollback()
        raise e
    finally:
        conn.close()

    # Notify waiting clients
    with _clipboard_changed_condition:
        _clipboard_changed_condition.notify_all()

def get_clipboard_entry(user_id):
    """Get the current clipboard entry for a user"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()

    cursor.execute('''
        SELECT content_type, content, metadata, created_at, version, client_id, filename
        FROM clipboard_entries
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT 1
    ''', (user_id,))

    result = cursor.fetchone()
    conn.close()

    if result:
        return {
            'content_type': result[0],
            'content': result[1],
            'metadata': result[2],
            'created_at': result[3],
            'version': result[4],
            'client_id': result[5],
            'filename': result[6]
        }
    return None

def get_clipboard_history(user_id, limit=10):
    """Get clipboard history for a user (excluding the current/most recent entry)"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()

    cursor.execute('''
        SELECT id, content_type, content, metadata, created_at, version, client_id, filename
        FROM clipboard_entries
        WHERE user_id = ?
        ORDER BY created_at DESC
        LIMIT ? OFFSET 1
    ''', (user_id, limit))

    results = cursor.fetchall()
    conn.close()

    history = []
    for result in results:
        history.append({
            'id': result[0],
            'content_type': result[1],
            'content': result[2],
            'metadata': result[3],
            'created_at': result[4],
            'version': result[5],
            'client_id': result[6],
            'filename': result[7]
        })

    return history

def get_clipboard_version(user_id):
    """Get the current clipboard version for a user from database"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT value FROM user_metadata WHERE user_id = ? AND key = "clipboard_version"', (user_id,))
    result = cursor.fetchone()
    conn.close()
    return result[0] if result else 0

def wait_for_clipboard_change(user_id, last_version, timeout=30):
    """Wait for clipboard to change from last_version for a user, with timeout"""
    start_time = time.time()
    
    with _clipboard_changed_condition:
        while time.time() - start_time < timeout:
            # Check current version from database
            current_version = get_clipboard_version(user_id)
            if current_version > last_version:
                return get_clipboard_entry(user_id)
            
            # Calculate remaining timeout
            remaining_timeout = timeout - (time.time() - start_time)
            if remaining_timeout <= 0:
                break
                
            # Wait for notification with remaining timeout
            _clipboard_changed_condition.wait(timeout=min(remaining_timeout, 0.5))
        
    return None  # Timeout

def hash_password(password):
    """Hash a password using SHA-256 with salt"""
    salt = secrets.token_hex(16)
    password_hash = hashlib.sha256((salt + password).encode()).hexdigest()
    return f"{salt}:{password_hash}"

def verify_password(password, stored_hash):
    """Verify a password against stored hash"""
    try:
        salt, hash_value = stored_hash.split(':')
        password_hash = hashlib.sha256((salt + password).encode()).hexdigest()
        return password_hash == hash_value
    except ValueError:
        return False

def create_user(username, password):
    """Create a new user"""
    password_hash = hash_password(password)
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    
    try:
        cursor.execute('''
            INSERT INTO users (username, password_hash, created_at)
            VALUES (?, ?, ?)
        ''', (username, password_hash, datetime.now().isoformat()))
        
        user_id = cursor.lastrowid
        
        # Initialize version counter for new user
        cursor.execute('''
            INSERT INTO user_metadata (user_id, key, value)
            VALUES (?, "clipboard_version", 0)
        ''', (user_id,))
        
        conn.commit()
        return user_id
        
    except sqlite3.IntegrityError:
        conn.rollback()
        raise ValueError("Username already exists")
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        conn.close()

def create_user_if_not_exists(username, password):
    """Create a user if it doesn't exist, return user_id"""
    user_id = get_user_id(username)
    if user_id is None:
        return create_user(username, password)
    return user_id

def get_user_id(username):
    """Get user ID by username"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT id FROM users WHERE username = ?', (username,))
    result = cursor.fetchone()
    conn.close()
    return result[0] if result else None

def authenticate_user(username, password):
    """Authenticate a user and return user_id if successful"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    cursor.execute('SELECT id, password_hash FROM users WHERE username = ?', (username,))
    result = cursor.fetchone()
    conn.close()
    
    if result and verify_password(password, result[1]):
        return result[0]
    return None