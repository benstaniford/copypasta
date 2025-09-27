#!/usr/bin/env python3
"""
CopyPasta Linux CLI Tool

A command-line interface for the CopyPasta clipboard sharing service.
Automatically detects copy (stdin) vs paste (stdout) mode.
"""

import sys
import os
import configparser
import requests
import json
import base64
from pathlib import Path


class CopyPastaClient:
    def __init__(self):
        self.config_path = Path.home() / '.config' / 'copyp.rc'
        self.config = None
        self.base_url = None
        self.username = None
        self.password = None
        self.session = requests.Session()
    
    def load_config(self):
        """Load configuration from ~/.config/copyp.rc"""
        if not self.config_path.exists():
            return False
        
        self.config = configparser.ConfigParser()
        self.config.read(self.config_path)
        
        if 'server' not in self.config:
            return False
        
        self.base_url = self.config.get('server', 'url', fallback=None)
        self.username = self.config.get('server', 'username', fallback=None)
        self.password = self.config.get('server', 'password', fallback=None)
        
        return all([self.base_url, self.username, self.password])
    
    def create_config(self):
        """Prompt user for configuration and save to ~/.config/copyp.rc"""
        print("CopyPasta CLI not configured. Please provide your server details:")
        
        self.base_url = input("Server URL (e.g., http://localhost:5000): ").strip()
        if not self.base_url:
            print("Error: Server URL is required")
            sys.exit(1)
        
        # Remove trailing slash if present
        self.base_url = self.base_url.rstrip('/')
        
        self.username = input("Username: ").strip()
        if not self.username:
            print("Error: Username is required")
            sys.exit(1)
        
        self.password = input("Password: ").strip()
        if not self.password:
            print("Error: Password is required")
            sys.exit(1)
        
        # Create config directory if it doesn't exist
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        
        # Save configuration
        config = configparser.ConfigParser()
        config['server'] = {
            'url': self.base_url,
            'username': self.username,
            'password': self.password
        }
        
        with open(self.config_path, 'w') as f:
            config.write(f)
        
        # Set restrictive permissions on config file
        os.chmod(self.config_path, 0o600)
        
        print(f"Configuration saved to {self.config_path}")
    
    def login(self):
        """Login to the CopyPasta service"""
        try:
            login_data = {
                'username': self.username,
                'password': self.password
            }
            
            response = self.session.post(f"{self.base_url}/login", data=login_data)
            
            if response.status_code == 200:
                return True
            else:
                print(f"Login failed: {response.status_code}")
                return False
        
        except requests.exceptions.RequestException as e:
            print(f"Error connecting to server: {e}")
            return False
    
    def copy_mode(self, data):
        """Send data to clipboard (copy mode)"""
        try:
            # Try to decode as base64 to detect if it's an image
            try:
                base64.b64decode(data)
                # If successful, treat as image
                payload = {
                    'content_type': 'image',
                    'content': data
                }
            except:
                # Not valid base64, treat as text
                payload = {
                    'content_type': 'text',
                    'content': data
                }
            
            response = self.session.post(f"{self.base_url}/api/paste", json=payload)
            
            if response.status_code == 200:
                print("Content copied to clipboard")
                return True
            else:
                print(f"Failed to copy: {response.status_code}")
                return False
        
        except requests.exceptions.RequestException as e:
            print(f"Error connecting to server: {e}")
            return False
    
    def paste_mode(self):
        """Retrieve data from clipboard (paste mode)"""
        try:
            response = self.session.get(f"{self.base_url}/api/clipboard")
            
            if response.status_code == 200:
                data = response.json()
                if data and 'content' in data:
                    # Only print the content, not the metadata
                    print(data['content'], end='')
                    return True
                else:
                    print("No content in clipboard", file=sys.stderr)
                    return False
            else:
                print(f"Failed to get clipboard: {response.status_code}", file=sys.stderr)
                return False
        
        except requests.exceptions.RequestException as e:
            print(f"Error connecting to server: {e}", file=sys.stderr)
            return False
    
    def run(self):
        """Main entry point"""
        # Load or create configuration
        if not self.load_config():
            self.create_config()
        
        # Login to service
        if not self.login():
            sys.exit(1)
        
        # Detect mode based on stdin
        if not sys.stdin.isatty():
            # Copy mode: read from stdin
            data = sys.stdin.read()
            if not self.copy_mode(data):
                sys.exit(1)
        else:
            # Paste mode: output to stdout
            if not self.paste_mode():
                sys.exit(1)


def main():
    """Entry point for the copyp command"""
    client = CopyPastaClient()
    client.run()


if __name__ == '__main__':
    main()