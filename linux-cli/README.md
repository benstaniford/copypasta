# CopyPasta Linux CLI

A command-line interface for the CopyPasta clipboard sharing service.

## Installation

Install from the .deb package:

```bash
sudo dpkg -i copyp_1.0.0_all.deb
sudo apt-get install -f  # Install dependencies if needed
```

## Usage

### First Run

On first run, `copyp` will prompt you for your server configuration:

```bash
$ copyp
CopyPasta CLI not configured. Please provide your server details:
Server URL (e.g., http://localhost:5000): http://your-server:5000
Username: your-username
Password: your-password
Configuration saved to /home/user/.config/copyp.rc
```

### Copy Mode (stdin)

Send data to your clipboard by piping it to `copyp`:

```bash
echo "Hello World" | copyp
cat file.txt | copyp
```

### Paste Mode (stdout)

Retrieve clipboard content by running `copyp` without stdin:

```bash
copyp
copyp > output.txt
```

## Configuration

Configuration is stored in `~/.config/copyp.rc` with restricted permissions (600).

Example configuration:
```ini
[server]
url = http://localhost:5000
username = myuser
password = mypassword
```

## Requirements

- Python 3.8 or later
- requests library
- Network access to your CopyPasta server