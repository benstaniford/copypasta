import sqlite3
import os
from datetime import datetime
import base64
import threading
import time

DATABASE_PATH = os.path.join(os.path.dirname(__file__), 'clipboard.db')

# Global version counter and lock for clipboard changes
_clipboard_version = 0
_clipboard_lock = threading.Lock()
_clipboard_changed_condition = threading.Condition(_clipboard_lock)

def init_db():
    """Initialize the database with required tables"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS clipboard_entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content_type TEXT NOT NULL,
            content TEXT NOT NULL,
            metadata TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            version INTEGER DEFAULT 1,
            client_id TEXT
        )
    ''')
    
    # Migration: Add new columns if they don't exist
    try:
        cursor.execute('ALTER TABLE clipboard_entries ADD COLUMN version INTEGER DEFAULT 1')
    except sqlite3.OperationalError:
        pass  # Column already exists
    
    try:
        cursor.execute('ALTER TABLE clipboard_entries ADD COLUMN client_id TEXT')
    except sqlite3.OperationalError:
        pass  # Column already exists
    
    conn.commit()
    conn.close()

def clear_clipboard():
    """Remove all existing clipboard entries"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    cursor.execute('DELETE FROM clipboard_entries')
    conn.commit()
    conn.close()

def save_clipboard_entry(content_type, content, metadata=None, client_id=None):
    """Save a new clipboard entry, removing any existing ones"""
    global _clipboard_version
    
    clear_clipboard()
    
    with _clipboard_lock:
        _clipboard_version += 1
        version = _clipboard_version
    
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        INSERT INTO clipboard_entries (content_type, content, metadata, created_at, version, client_id)
        VALUES (?, ?, ?, ?, ?, ?)
    ''', (content_type, content, metadata, datetime.now().isoformat(), version, client_id))
    
    conn.commit()
    conn.close()
    
    # Notify waiting clients
    with _clipboard_changed_condition:
        _clipboard_changed_condition.notify_all()

def get_clipboard_entry():
    """Get the current clipboard entry"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT content_type, content, metadata, created_at, version, client_id
        FROM clipboard_entries
        ORDER BY created_at DESC
        LIMIT 1
    ''')
    
    result = cursor.fetchone()
    conn.close()
    
    if result:
        return {
            'content_type': result[0],
            'content': result[1],
            'metadata': result[2],
            'created_at': result[3],
            'version': result[4],
            'client_id': result[5]
        }
    return None

def get_clipboard_version():
    """Get the current clipboard version"""
    with _clipboard_lock:
        return _clipboard_version

def wait_for_clipboard_change(last_version, timeout=30):
    """Wait for clipboard to change from last_version, with timeout"""
    start_time = time.time()
    
    with _clipboard_changed_condition:
        while time.time() - start_time < timeout:
            current_version = _clipboard_version
            if current_version > last_version:
                # Release lock before database access
                _clipboard_changed_condition.release()
                try:
                    return get_clipboard_entry()
                finally:
                    _clipboard_changed_condition.acquire()
            
            # Calculate remaining timeout
            remaining_timeout = timeout - (time.time() - start_time)
            if remaining_timeout <= 0:
                break
                
            # Wait for notification with remaining timeout
            _clipboard_changed_condition.wait(timeout=min(remaining_timeout, 0.5))
        
    return None  # Timeout