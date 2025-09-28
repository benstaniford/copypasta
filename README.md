# CopyPasta 📋

Cross-device clipboard sharing through a web interface. Share text and images between your devices instantly.  A docker container maintains the clipboard history and your devices can access it via the web or via native clients that watch system clipboards.

## 🚀 Quick Start

### Docker (Recommended)

1. **Download and run:**
   ```bash
   docker run -d -p 5000:5000 --name copypasta nerwander/copypasta:latest
   ```

2. **Or use docker-compose:**
   ```bash
   curl -O https://raw.githubusercontent.com/your-repo/copypasta/main/docker-compose.yml
   docker compose up -d
   ```

3. **Access:** Open `http://localhost:5000` and register a new account or login with existing credentials

### Docker Compose File

```yaml
services:
  copypasta:
    image: nerwander/copypasta:latest
    container_name: copypasta
    ports:
      - "5000:5000"
    restart: unless-stopped
    environment:
      - FLASK_ENV=production
      - SECRET_KEY=your-super-secret-key-change-this-in-production
    healthcheck:
      test: ["CMD", "python", "-c", "import requests; requests.get('http://localhost:5000/health', timeout=5)"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
```

## 📱 Client Applications

- **Web Interface** - Works on any device with a browser
- **macOS Client** - Native macOS application with system clipboard integration
- **Windows Client** - Native Windows application with system tray support
- **Linux CLI** - Command-line tool for Linux systems

Check the [Releases page](https://github.com/your-repo/copypasta/releases) for the latest client downloads.

### Linux CLI Installation

```bash
# Download from releases page
sudo dpkg -i copyp_*.deb
sudo apt-get install -f

# Configure and use
copyp  # First run prompts for server URL and credentials
echo "Hello World" | copyp  # Copy text
copyp  # Paste text
```

## 📱 How to Use

### Multi-User Support
- **Registration:** Create new accounts through the web interface at `/register`
- **Individual Clipboards:** Each user has their own clipboard history and content
- **Secure Authentication:** Password-protected accounts with persistent sessions

### Using the Application

1. **Web Interface:**
   - Register a new account or login with existing credentials
   - Paste content in the text area or upload images
   - View clipboard history of your previous entries
   - Content syncs instantly across all your logged-in devices
   - Click "Copy to Device" to copy text to your clipboard

2. **Cross-Device Access:**
   - Replace `localhost` with your computer's IP address
   - Example: `http://192.168.1.100:5000`
   - Ensure port 5000 is accessible on your network

## ⚙️ Configuration

### Security Settings
With multi-user support, you no longer need to set default credentials. Users can register their own accounts through the web interface.

```yaml
environment:
  - SECRET_KEY=your-very-long-random-secret-key-change-this-in-production
  - FLASK_ENV=production
```

**Important:** Always change the `SECRET_KEY` in production for secure session management.

## ✨ Features

- **Multi-user support** with individual accounts and clipboard histories
- **Clipboard history** - Access your previous clipboard entries
- **Real-time sync** across all devices with long-polling
- **Text and image support** (PNG, JPG, GIF)
- **Native clients** for macOS, Windows, and Linux
- **Push notifications** so your clients know when the central clipboard has changed
- **Persistent login** until logout
- **Mobile-friendly** responsive design
- **Secure authentication** with user registration
- **Docker deployment** for easy setup

## 🔒 Security Notes

- **Change SECRET_KEY** for production deployments
- **Use HTTPS** in production environments  
- **Firewall protection** for public deployments
- **User registration** - Each user has their own secure account

## 🆘 Troubleshooting

**Can't access from other devices:**
- Check firewall settings and port 5000 access
- Use your computer's IP address, not `localhost`

**Login/Registration issues:**
- Clear browser cookies and try again
- Ensure your username doesn't already exist during registration
- Check that your password meets the minimum 4-character requirement

**View logs:**
```bash
docker compose logs -f copypasta
```

## 📝 License

MIT License - feel free to modify and adapt for your needs.
