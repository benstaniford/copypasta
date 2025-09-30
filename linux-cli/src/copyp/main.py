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
import socket
import uuid
from pathlib import Path


class CopyPastaClient:
    def __init__(self):
        self.config_path = Path.home() / '.config' / 'copyp.rc'
        self.config = None
        self.base_url = None
        self.username = None
        self.password = None
        self.session = requests.Session()
        self.client_id = self._generate_client_id()
    
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
    
    def _generate_client_id(self):
        """Generate a unique client ID based on hostname, username, and a random component"""
        hostname = socket.gethostname()
        username = os.getenv('USER', os.getenv('USERNAME', 'unknown'))
        random_part = str(uuid.uuid4())[:8]  # First 8 chars of UUID
        return f"{hostname}-{username}-{random_part}"
    
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
    
    def copy_mode(self, data, filename=None):
        """Send data to clipboard (copy mode)"""
        try:
            # Detect content type
            content_type = 'text'
            content = data

            # Check if data is binary (contains null bytes or other non-text characters)
            if self._is_binary(data):
                # Binary file - encode as base64
                content_type = 'file'
                if isinstance(data, str):
                    data = data.encode('latin-1')  # Preserve binary data
                content = 'data:application/octet-stream;base64,' + base64.b64encode(data).decode('ascii')
            else:
                # Text content
                if isinstance(data, bytes):
                    content = data.decode('utf-8', errors='replace')
                else:
                    content = data

            payload = {
                'type': content_type,
                'content': content,
                'client_id': self.client_id
            }

            if filename:
                payload['filename'] = filename

            response = self.session.post(f"{self.base_url}/api/paste", json=payload)

            if response.status_code == 200:
                if content_type == 'file':
                    print(f"File copied to clipboard: {filename or 'binary data'}")
                else:
                    print("Content copied to clipboard")
                return True
            else:
                print(f"Failed to copy: {response.status_code}")
                return False

        except requests.exceptions.RequestException as e:
            print(f"Error connecting to server: {e}")
            return False

    def _is_binary(self, data):
        """Check if data appears to be binary"""
        if isinstance(data, bytes):
            # Check for null bytes or high proportion of non-printable characters
            if b'\x00' in data:
                return True
            # Sample the data to check for binary content
            sample = data[:8192] if len(data) > 8192 else data
            non_text_chars = sum(1 for b in sample if b < 32 and b not in (9, 10, 13))
            return non_text_chars > len(sample) * 0.3
        elif isinstance(data, str):
            # String data with control characters might be binary read as text
            non_text_chars = sum(1 for c in data[:8192] if ord(c) < 32 and c not in '\t\n\r')
            return non_text_chars > len(data[:8192]) * 0.3
        return False
    
    def paste_mode(self):
        """Retrieve data from clipboard (paste mode)"""
        try:
            response = self.session.get(f"{self.base_url}/api/clipboard")

            if response.status_code == 200:
                data = response.json()
                if data and data.get('data') and 'content' in data['data']:
                    content = data['data']['content']
                    content_type = data['data'].get('content_type', 'text')

                    # Handle file/binary content
                    if content_type == 'file':
                        # Decode base64 file content
                        if content.startswith('data:application/octet-stream;base64,'):
                            base64_data = content.split(',', 1)[1]
                            binary_data = base64.b64decode(base64_data)
                            # Write binary data to stdout
                            sys.stdout.buffer.write(binary_data)
                            sys.stdout.buffer.flush()
                        else:
                            print("Error: Invalid file format", file=sys.stderr)
                            return False
                    else:
                        # Text content - print normally
                        print(content, end='')

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
            # Copy mode: read from stdin (binary safe)
            data = sys.stdin.buffer.read()

            # Try to extract filename from command line args or /proc
            filename = None
            if len(sys.argv) > 1:
                # Check if argument looks like a filename
                arg = sys.argv[1]
                if not arg.startswith('-'):
                    filename = os.path.basename(arg)

            # If no filename from args, try to detect from /proc (Linux)
            if not filename:
                try:
                    # Try to read the symlink from /proc/self/fd/0 to get source file
                    stdin_link = os.readlink('/proc/self/fd/0')
                    if stdin_link and not stdin_link.startswith('pipe:') and os.path.exists(stdin_link):
                        filename = os.path.basename(stdin_link)
                except (OSError, FileNotFoundError):
                    pass

            if not self.copy_mode(data, filename):
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