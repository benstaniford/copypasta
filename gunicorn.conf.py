# Gunicorn configuration file for production
import multiprocessing
import sys
import os

# Add current directory to Python path for imports
sys.path.insert(0, os.path.dirname(__file__))

try:
    from version import get_cached_version, get_numeric_version
    app_version = get_cached_version()
    numeric_version = get_numeric_version(app_version)
    print(f"🚀 CopyPasta v{numeric_version} starting with Gunicorn...")
except Exception as e:
    print(f"⚠️  Could not determine version: {e}")
    print("🚀 CopyPasta starting with Gunicorn...")

# Server socket
bind = "0.0.0.0:5000"
backlog = 2048

# Worker processes
workers = multiprocessing.cpu_count() * 2 + 1
worker_class = "sync"
worker_connections = 1000
timeout = 30
keepalive = 2

# Restart workers after this many requests, to help prevent memory leaks
max_requests = 1000
max_requests_jitter = 100

# Logging
accesslog = "-"
errorlog = "-"
loglevel = "info"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# Process naming
proc_name = "copypasta"

# Security
limit_request_line = 0
limit_request_fields = 100
limit_request_field_size = 8190

# Performance
preload_app = True
