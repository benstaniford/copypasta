#!/usr/bin/env python3
"""
Quick test script for the long polling functionality
"""

import requests
import json
import threading
import time

# Test configuration
SERVER_URL = "http://localhost:5000"
USERNAME = "user"
PASSWORD = "password"

def login_and_get_session():
    """Login and return session"""
    session = requests.Session()
    
    # Login
    response = session.post(f"{SERVER_URL}/login", data={
        'username': USERNAME,
        'password': PASSWORD
    })
    
    if response.status_code != 200:
        raise Exception(f"Login failed: {response.status_code}")
    
    return session

def test_polling():
    """Test the polling endpoint"""
    print("Testing long polling endpoint...")
    
    try:
        session = login_and_get_session()
        
        # Test immediate response (should timeout or return current state)
        print("Testing immediate poll...")
        response = session.get(f"{SERVER_URL}/api/poll?version=0&timeout=2")
        
        if response.status_code == 200:
            data = response.json()
            print(f"Poll response: {json.dumps(data, indent=2)}")
        else:
            print(f"Poll failed: {response.status_code}")
            
        # Test posting new content
        print("Testing clipboard update...")
        paste_response = session.post(f"{SERVER_URL}/api/paste", json={
            'type': 'text',
            'content': f'Test content {int(time.time())}'
        })
        
        if paste_response.status_code == 200:
            print("Content posted successfully")
        else:
            print(f"Content post failed: {paste_response.status_code}")
            
        # Test polling for the change
        print("Testing poll for change...")
        response = session.get(f"{SERVER_URL}/api/poll?version=0&timeout=5")
        
        if response.status_code == 200:
            data = response.json()
            print(f"Poll after change: {json.dumps(data, indent=2)}")
        else:
            print(f"Poll after change failed: {response.status_code}")
            
    except Exception as e:
        print(f"Test error: {e}")

if __name__ == "__main__":
    test_polling()