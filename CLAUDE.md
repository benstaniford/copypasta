# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is CopyPasta, a cross-device clipboard sharing application built with Flask. It allows multiple users to share text and images between their devices through a web interface and native clients. The application features multi-user authentication, clipboard history, SQLite database storage, persistent sessions, real-time content synchronization, and is designed for containerized deployment using Docker and Gunicorn.

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
- **app.py**: Main Flask application with multi-user clipboard functionality and authentication
- **database.py**: SQLite database operations for users, clipboard entries, and history
- **gunicorn.conf.py**: Production WSGI server configuration with optimized worker settings
- **templates/**: HTML templates for web interface (index.html for clipboard UI, login.html, register.html)
- **macos/**: Native macOS client with system clipboard integration
- **win-copypasta/**: Native Windows client with system tray support
- **linux-cli/**: Command-line tool for Linux systems

### Key Components
1. **Multi-User System**: Individual user accounts with separate clipboard histories
2. **Clipboard System**: Store and retrieve text/image content with metadata per user
3. **Authentication System**: User registration and login with secure password hashing
4. **Clipboard History**: Access to previous clipboard entries with configurable limits
5. **Database**: SQLite database with users, clipboard entries, and version tracking
6. **API Endpoints**: RESTful endpoints for clipboard operations (/api/paste, /api/clipboard, /api/clipboard/history)
7. **Real-time Sync**: Long-polling for instant updates across devices with client filtering
8. **Native Clients**: Cross-platform desktop applications for seamless clipboard integration
9. **Image Processing**: Base64 image validation and display using Pillow
10. **Security**: Non-root container execution, input validation, secure session management

### Database Schema
```sql
-- Users table for multi-user authentication
CREATE TABLE users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Clipboard entries with user association and versioning
CREATE TABLE clipboard_entries (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,    -- References users.id
    content_type TEXT NOT NULL,  -- 'text', 'image', or 'rich'
    content TEXT NOT NULL,       -- Text content or base64 image data
    metadata TEXT,               -- JSON metadata (timestamp, user_agent)
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    version INTEGER DEFAULT 1,   -- For real-time sync versioning
    client_id TEXT,              -- Client identifier for filtering
    FOREIGN KEY (user_id) REFERENCES users (id)
);

-- User metadata for version tracking
CREATE TABLE user_metadata (
    user_id INTEGER NOT NULL,
    key TEXT NOT NULL,
    value INTEGER NOT NULL,
    PRIMARY KEY (user_id, key),
    FOREIGN KEY (user_id) REFERENCES users (id)
);
```

### Docker Multi-Stage Build
- **Builder stage**: Compiles Python packages including Pillow with build dependencies
- **Runtime stage**: Minimal image with runtime requirements and SQLite database
- Uses Python 3.11 slim base image for security and size optimization

### Configuration
Environment variables for deployment:
- `SECRET_KEY`: Flask session secret (required - change in production)
- `FLASK_ENV`: Environment setting (production/development)

**Note**: With multi-user support, individual users register their own accounts through the web interface. Default credentials are no longer used.

## Development Guidelines

### Security Practices
- All routes except `/health`, `/login`, and `/register` require authentication
- Multi-user system with secure password hashing using bcrypt
- Persistent session-based authentication with 10-year session lifetime
- User registration with username uniqueness validation
- Input validation for text and image content
- Base64 image validation and Pillow verification
- Non-root user execution in container
- SQLite database with prepared statements to prevent injection

### Performance Considerations
- Gunicorn multi-worker configuration scales with CPU cores
- SQLite database with per-user clipboard history management
- Long-polling for real-time updates with configurable timeouts
- Client filtering to prevent echo-back of content to originating client
- Version tracking for efficient change detection
- Minimal Docker image for fast deployment
- Base64 image encoding for efficient storage and transmission

### Clipboard Functionality
- **Content Types**: Supports 'text', 'image', and 'rich' content types
- **Multi-User Storage**: Each user has their own clipboard history
- **History Management**: Configurable limits for clipboard history entries
- **Metadata**: Tracks creation timestamp, user agent, and client information
- **Cross-Device**: Real-time synchronization through web interface and native clients
- **Native Integration**: Desktop clients integrate with system clipboards
- **Copy Operations**: Browser clipboard API integration for text content

### Testing Strategy
- Unit tests cover clipboard operations, authentication, and API endpoints
- Import tests verify all dependencies including Pillow work correctly
- Database tests ensure SQLite operations function properly
- Mock authentication in tests using Flask test client sessions
- API endpoint tests validate clipboard functionality

### File Organization
```
/app.py                 # Main application logic and multi-user clipboard routes
/database.py            # SQLite database operations for users and clipboard entries
/templates/             # Jinja2 HTML templates (clipboard UI, login, registration)
/macos/                 # Native macOS Swift application
/win-copypasta/         # Native Windows C# application with installer
/linux-cli/             # Command-line tool for Linux systems
/tests/                 # Unit tests and import verification
/scripts/               # Build, setup, and release automation
/test-docker/           # Docker container testing
/clipboard.db           # SQLite database (created at runtime)
```

### API Endpoints
- `POST /api/paste`: Save content to clipboard (text, image, or rich content)
- `GET /api/clipboard`: Retrieve current clipboard content for authenticated user
- `GET /api/clipboard/history`: Retrieve clipboard history with configurable limit (1-50 entries)
- `GET /api/poll`: Long-polling endpoint for real-time clipboard changes with client filtering
- `POST /login`: User authentication
- `POST /register`: User registration
- `GET /logout`: User logout
- `GET /api/data`: Legacy endpoint for backward compatibility
- `GET /health`: Health check endpoint for container orchestration

### Deployment Notes
- Uses multi-stage Docker build to minimize image size
- SQLite database with multi-user tables created automatically on first run
- Gunicorn configuration optimized for container deployment
- Health checks ensure container reliability in orchestrated environments
- Persistent sessions maintain login across browser sessions for each user
- Native client applications available for macOS, Windows, and Linux
- Scripts provide automated setup, testing, and release management across platforms

### Content Type Handling
- **Text Content**: Plain text with whitespace preservation
- **Image Content**: Base64-encoded images (PNG, JPG, GIF) with Pillow validation
- **Rich Content**: HTML content with size limits (10MB max)
- **Metadata**: JSON-encoded timestamps, user agent, and client information
- **History**: Per-user storage with configurable entry limits
- **Preview**: Real-time content display with appropriate rendering for each type