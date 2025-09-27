# CopyPasta Windows Client

A Windows system tray application that automatically syncs your clipboard with the CopyPasta server for cross-device clipboard sharing.

## Features

- **Automatic Clipboard Monitoring**: Detects when you copy text, rich text, or images
- **Smart Content Detection**: Automatically determines content type (text, rich text, or images)
- **System Tray Integration**: Runs quietly in the background with tray icon
- **Configurable Settings**: Set server endpoint, username, and password
- **Auto-start Support**: Optional startup with Windows
- **Connection Testing**: Test your server connection before saving settings

## Requirements

- Windows 10 or later
- .NET 6.0 Runtime
- CopyPasta server running (Docker container or local installation)

## Installation

1. **Build from Source**:
   ```bash
   cd win-copypasta
   dotnet build --configuration Release
   ```

2. **Run the Application**:
   ```bash
   dotnet run
   ```

   Or after building:
   ```bash
   ./bin/Release/net6.0-windows/CopyPasta.exe
   ```

## Configuration

1. **First Run**: Right-click the tray icon and select "Settings..."
2. **Server Endpoint**: Enter your CopyPasta server URL (e.g., `http://localhost:5000`)
3. **Credentials**: Enter your username and password
4. **Test Connection**: Click "Test Connection" to verify settings
5. **Auto-start**: Optionally enable "Start with Windows"

## Usage

Once configured, the application will:

1. **Monitor Clipboard**: Automatically detect when you copy content
2. **Upload Content**: Send copied content to your CopyPasta server
3. **Show Notifications**: Display balloon tips for successful uploads or errors
4. **Sync Across Devices**: Access your clipboard from any device with CopyPasta

## Supported Content Types

- **Plain Text**: Regular text content
- **Rich Text**: Formatted text with bold, italic, etc.
- **Images**: PNG, JPEG, and other image formats

## Tray Icon Menu

- **CopyPasta**: Application title (disabled)
- **Settings...**: Open configuration dialog
- **Exit**: Close the application

## Settings Storage

Settings are stored in:
```
%APPDATA%\CopyPasta\settings.json
```

## Auto-start Registry

When "Start with Windows" is enabled, the application adds itself to:
```
HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
```

## Troubleshooting

### Connection Issues
- Verify server endpoint URL is correct
- Ensure CopyPasta server is running
- Check firewall settings
- Test connection using the "Test Connection" button

### Authentication Issues
- Verify username and password are correct
- Check if credentials work in the web interface
- Ensure server authentication is enabled

### Clipboard Not Syncing
- Check if application is running (look for tray icon)
- Verify settings are configured correctly
- Look for error notifications in system tray
- Restart the application

## Development

### Project Structure
- `Program.cs` - Application entry point
- `TrayApplicationContext.cs` - Main tray application logic
- `SettingsForm.cs` - Configuration dialog
- `Settings.cs` - Settings management and persistence
- `ClipboardMonitor.cs` - Clipboard change detection
- `CopyPastaClient.cs` - HTTP client for server communication

### Building
```bash
# Debug build
dotnet build

# Release build
dotnet build --configuration Release

# Publish single-file executable
dotnet publish --configuration Release --runtime win-x64 --self-contained true -p:PublishSingleFile=true
```

### Dependencies
- **.NET 6.0**: Target framework
- **Windows Forms**: UI framework
- **Newtonsoft.Json**: JSON serialization

## Security Notes

- Credentials are stored in plain text in the settings file
- Consider using Windows Credential Manager for production use
- Network communication is HTTP (not HTTPS) by default
- Clipboard content is transmitted to the configured server

## License

This project is part of the CopyPasta application suite.