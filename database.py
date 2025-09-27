import sqlite3
import os
from datetime import datetime
import base64

DATABASE_PATH = os.path.join(os.path.dirname(__file__), 'clipboard.db')

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
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    conn.commit()
    conn.close()

def clear_clipboard():
    """Remove all existing clipboard entries"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    cursor.execute('DELETE FROM clipboard_entries')
    conn.commit()
    conn.close()

def save_clipboard_entry(content_type, content, metadata=None):
    """Save a new clipboard entry, removing any existing ones"""
    clear_clipboard()
    
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        INSERT INTO clipboard_entries (content_type, content, metadata, created_at)
        VALUES (?, ?, ?, ?)
    ''', (content_type, content, metadata, datetime.now().isoformat()))
    
    conn.commit()
    conn.close()

def get_clipboard_entry():
    """Get the current clipboard entry"""
    conn = sqlite3.connect(DATABASE_PATH)
    cursor = conn.cursor()
    
    cursor.execute('''
        SELECT content_type, content, metadata, created_at
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
            'created_at': result[3]
        }
    return None