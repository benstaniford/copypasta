# CopyPasta 📋

A cross-device clipboard sharing application built with Flask. Share text and images seamlessly between your devices through a simple web interface.

## ✨ Features

- **Cross-Device Clipboard**: Share content between phones, tablets, computers, and any device with a web browser
- **Multi-Content Support**: Text, rich text, and images (PNG, JPG, GIF, etc.)
- **Real-Time Sync**: Auto-refresh every 10 seconds to keep all devices in sync
- **One-Click Copy**: Copy shared content directly to your device's clipboard
- **Persistent Login**: Stay logged in until you explicitly sign out
- **Secure Storage**: SQLite database with metadata tracking
- **Production Ready**: Docker deployment with Gunicorn WSGI server
- **Mobile Friendly**: Responsive design works on all screen sizes

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- Any modern web browser

### Using Docker (Recommended)

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd copypasta
   ```

2. **Start the application**
   ```bash
   docker compose up --build -d
   ```

3. **Access the application**
   - Open your browser to `http://localhost:5000`
   - Login with default credentials: `user` / `password`
   - Start sharing content between your devices!

### Local Development

1. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

2. **Run the application**
   ```bash
   python app.py
   ```

## 📱 How to Use

1. **Login** on any device using your credentials
2. **Paste Content**: 
   - Type or paste text in the text area
   - OR upload an image using the file picker
   - Click "Save to Clipboard"
3. **Copy on Another Device**:
   - Open CopyPasta on any other device
   - View the preview of your shared content
   - Click "Copy to Device" for text content
   - Right-click and save images

## ⚙️ Configuration

Configure the application using environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `APP_USERNAME` | `user` | Authentication username |
| `APP_PASSWORD` | `password` | Authentication password |
| `SECRET_KEY` | `your-secret-key-change-this-in-production` | Flask session secret |

### Docker Compose Configuration

```yaml
environment:
  - APP_USERNAME=myuser
  - APP_PASSWORD=mypassword
  - SECRET_KEY=your-very-secure-secret-key
```

## 🔧 API Endpoints

### Web Interface
- `GET /` - Main clipboard interface (requires authentication)
- `GET /login` - Login page
- `POST /login` - Authentication endpoint
- `GET /logout` - Logout endpoint

### API Endpoints
- `GET /health` - Health check endpoint
- `GET /api/clipboard` - Get current clipboard content
- `POST /api/paste` - Save new content to clipboard
- `GET /api/data` - Legacy API endpoint for compatibility

### API Usage Examples

**Get clipboard content:**
```bash
curl -H "Cookie: session=..." http://localhost:5000/api/clipboard
```

**Save text content:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Cookie: session=..." \
  -d '{"type":"text","content":"Hello from API!"}' \
  http://localhost:5000/api/paste
```

## 🐳 Docker Details

### Multi-Stage Build
- **Builder stage**: Compiles Python packages including Pillow for image processing
- **Runtime stage**: Minimal production image with SQLite database
- **Base**: Python 3.11 slim for security and size optimization

### Persistent Data
- SQLite database stored in container at `/app/clipboard.db`
- Mount a volume to persist data across container restarts:
  ```yaml
  volumes:
    - ./data:/app/data
  ```

## 🧪 Testing

### Run All Tests
```bash
./scripts/test-all
```

### Individual Test Components
```bash
# Python unit tests
python -m pytest tests/ -v

# Import verification
python tests/test_imports.py

# Docker container tests
./test-docker/test-container.sh
```

## 📁 Project Structure

```
├── app.py                 # Main Flask application
├── database.py           # SQLite database operations
├── requirements.txt       # Python dependencies (Flask, Pillow, etc.)
├── Dockerfile            # Multi-stage Docker build
├── docker-compose.yml    # Development compose file
├── gunicorn.conf.py      # Production server configuration
├── templates/            # HTML templates
│   ├── index.html       # Main clipboard interface
│   └── login.html       # Login page
├── tests/               # Test suite
├── scripts/             # Automation scripts
├── test-docker/         # Container testing
└── clipboard.db         # SQLite database (created at runtime)
```

## 🚀 Deployment

### Production Deployment
1. **Set secure credentials**
   ```bash
   export APP_USERNAME="your-secure-username"
   export APP_PASSWORD="your-secure-password"
   export SECRET_KEY="your-very-long-random-secret-key"
   ```

2. **Deploy with Docker Compose**
   ```bash
   docker compose -f docker-compose.prod.yml up -d
   ```

3. **Configure reverse proxy** (nginx, traefik, etc.)
4. **Set up SSL certificates** for HTTPS access

### Network Access
For cross-device access, ensure the application is accessible on your local network:
```yaml
ports:
  - "0.0.0.0:5000:5000"  # Allow access from other devices
```

Then access from other devices using your computer's IP: `http://YOUR-IP:5000`

## 🔒 Security Considerations

- **Change default credentials** before exposing to network
- **Use HTTPS** in production to protect login credentials
- **Firewall access** if deploying on public networks
- **Regular backups** of clipboard.db if storing important content
- **Monitor access logs** for unauthorized usage

## 💡 Use Cases

- **Developer Workflow**: Share code snippets between development machine and testing devices
- **Content Creation**: Move text drafts between phone and computer
- **Image Sharing**: Quick photo sharing between devices without cloud services
- **Meeting Notes**: Share meeting links or notes between laptop and phone
- **Cross-Platform**: Bridge content between iOS, Android, Windows, Mac, Linux

## 🆘 Troubleshooting

### Common Issues

**Can't access from other devices:**
- Check firewall settings
- Ensure port 5000 is open
- Use correct IP address (not localhost)

**Images not displaying:**
- Check image file size (large files may take time)
- Ensure valid image format (PNG, JPG, GIF)
- Check browser console for errors

**Login issues:**
- Verify credentials in environment variables
- Clear browser cookies and try again
- Check container logs: `docker compose logs flask-app`

### Development

```bash
# View application logs
docker compose logs -f flask-app

# Access container shell
docker compose exec flask-app sh

# Test database connection
python -c "from database import get_clipboard_entry; print(get_clipboard_entry())"
```

## 📝 License

This project is provided as-is for personal and educational use. Feel free to modify and adapt for your needs.