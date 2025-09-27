# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is CopyPasta, a cross-device clipboard sharing application built with Flask. It allows users to share text and images between devices through a web interface. The application features SQLite database storage, persistent sessions, real-time content synchronization, and is designed for containerized deployment using Docker and Gunicorn.

## Development Commands

### Building and Running
```bash
# Quick start using Docker Hub image
docker compose up -d

# Build and run locally (development)
docker compose up --build -d

# Stop the application
docker compose down

# View application logs
docker compose logs -f copypasta
```

### Testing

#### Comprehensive Test Suite (Recommended)
```bash
# Run all tests: Python unit tests + Docker container tests
./scripts/test-all

# This runs the complete test suite:
# 1. Python import tests
# 2. Python unit tests  
# 3. Docker container tests
```

#### Individual Test Components

**Python Unit Tests**
```bash
# Run import tests (verify all dependencies work)
python tests/test_imports.py

# Run unit tests
python -m pytest tests/test_simple.py -v

# Run all tests
python -m unittest discover tests/
```

**Docker Container Testing**
```bash
# Run comprehensive Docker container test suite
./test-docker/test-container.sh

# This test script validates:
# - Docker build process
# - Container startup and health
# - Web interface accessibility
# - Clipboard API functionality
# - Authentication system
```

### Release Management
```bash
# Create new release (increments patch version automatically)
./scripts/make-release

# Setup application for end users
./scripts/setup.sh  # Linux/macOS
./scripts/setup.ps1  # Windows PowerShell
```

### Local Development
```bash
# Install dependencies (including Pillow for image processing)
pip install -r requirements.txt

# Run Flask development server (not recommended for production)
python app.py

# Production server (Gunicorn - used in Docker)
gunicorn --config gunicorn.conf.py app:app
```

## Architecture Overview

### Core Application Structure
- **app.py**: Main Flask application with clipboard functionality and authentication
- **database.py**: SQLite database operations for clipboard entries
- **gunicorn.conf.py**: Production WSGI server configuration with optimized worker settings
- **templates/**: HTML templates for web interface (index.html for clipboard UI, login.html)

### Key Components
1. **Clipboard System**: Store and retrieve text/image content with metadata
2. **Authentication System**: Persistent session-based login with environment variable credentials
3. **Database**: SQLite database with automatic initialization and single-entry storage
4. **API Endpoints**: RESTful endpoints for clipboard operations (/api/paste, /api/clipboard)
5. **Real-time UI**: Auto-refreshing interface with content preview and copy functionality
6. **Image Processing**: Base64 image validation and display using Pillow
7. **Security**: Non-root container execution, input validation, secure session management

### Database Schema
```sql
CREATE TABLE clipboard_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_type TEXT NOT NULL,  -- 'text' or 'image'
    content TEXT NOT NULL,       -- Text content or base64 image data
    metadata TEXT,               -- JSON metadata (timestamp, user_agent)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Docker Multi-Stage Build
- **Builder stage**: Compiles Python packages including Pillow with build dependencies
- **Runtime stage**: Minimal image with runtime requirements and SQLite database
- Uses Python 3.11 slim base image for security and size optimization

### Configuration
Environment variables for deployment:
- `APP_USERNAME`: Authentication username (default: 'user')
- `APP_PASSWORD`: Authentication password (default: 'password')  
- `SECRET_KEY`: Flask session secret (change in production)

## Development Guidelines

### Security Practices
- All routes except `/health` and `/login` require authentication
- Persistent session-based authentication with 10-year session lifetime
- Input validation for text and image content
- Base64 image validation and Pillow verification
- Non-root user execution in container
- SQLite database with prepared statements to prevent injection

### Performance Considerations
- Gunicorn multi-worker configuration scales with CPU cores
- SQLite database with single-entry optimization (old entries automatically removed)
- Minimal Docker image for fast deployment
- Auto-refresh every 10 seconds to sync content across devices
- Base64 image encoding for efficient storage and transmission

### Clipboard Functionality
- **Content Types**: Supports 'text' and 'image' content types
- **Storage**: Single clipboard entry (new content replaces old)
- **Metadata**: Tracks creation timestamp and user agent
- **Cross-Device**: Real-time synchronization through web interface
- **Copy Operations**: Browser clipboard API integration for text content

### Testing Strategy
- Unit tests cover clipboard operations, authentication, and API endpoints
- Import tests verify all dependencies including Pillow work correctly
- Database tests ensure SQLite operations function properly
- Mock authentication in tests using Flask test client sessions
- API endpoint tests validate clipboard functionality

### File Organization
```
/app.py                 # Main application logic and clipboard routes
/database.py            # SQLite database operations
/templates/             # Jinja2 HTML templates (clipboard UI)
/tests/                 # Unit tests and import verification
/scripts/               # Build, setup, and release automation
/test-docker/           # Docker container testing
/clipboard.db           # SQLite database (created at runtime)
```

### API Endpoints
- `POST /api/paste`: Save content to clipboard (text or base64 image)
- `GET /api/clipboard`: Retrieve current clipboard content
- `GET /api/data`: Legacy endpoint for backward compatibility
- `GET /health`: Health check endpoint for container orchestration

### Deployment Notes
- Uses multi-stage Docker build to minimize image size
- SQLite database created automatically on first run
- Gunicorn configuration optimized for container deployment
- Health checks ensure container reliability in orchestrated environments
- Persistent sessions maintain login across browser sessions
- Scripts provide automated setup and testing across platforms

### Content Type Handling
- **Text Content**: Plain text with whitespace preservation
- **Image Content**: Base64-encoded images (PNG, JPG, GIF) with Pillow validation
- **Metadata**: JSON-encoded timestamps and user agent information
- **Preview**: Real-time content display with appropriate rendering for each type