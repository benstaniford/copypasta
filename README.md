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

3. **Access:** Open `http://localhost:5000` and login with `user` / `password`

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
      - APP_USERNAME=user
      - APP_PASSWORD=password
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
- **Linux CLI** - Command-line tool for Linux systems
- **Windows Client** - Native Windows application

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

1. **Web Interface:**
   - Login on any device
   - Paste content in the text area or upload images
   - Content appears instantly on all logged-in devices
   - Click "Copy to Device" to copy text to your clipboard

2. **Cross-Device Access:**
   - Replace `localhost` with your computer's IP address
   - Example: `http://192.168.1.100:5000`
   - Ensure port 5000 is accessible on your network

## ⚙️ Configuration

Change default credentials for security:

```yaml
environment:
  - APP_USERNAME=your-username
  - APP_PASSWORD=your-secure-password
  - SECRET_KEY=your-very-long-random-secret-key
```

## ✨ Features

- **Real-time sync** across all devices
- **Text and image support** (PNG, JPG, GIF)
- **Push notifications** so your clients know when the central clipboard has changed
- **Persistent login** until logout
- **Mobile-friendly** responsive design
- **Secure authentication** with configurable credentials
- **Docker deployment** for easy setup

## 🔒 Security Notes

- **Change default credentials** before network access
- **Use HTTPS** in production environments
- **Firewall protection** for public deployments

## 🆘 Troubleshooting

**Can't access from other devices:**
- Check firewall settings and port 5000 access
- Use your computer's IP address, not `localhost`

**Login issues:**
- Verify environment variables are set correctly
- Clear browser cookies

**View logs:**
```bash
docker compose logs -f copypasta
```

## 📝 License

MIT License - feel free to modify and adapt for your needs.
