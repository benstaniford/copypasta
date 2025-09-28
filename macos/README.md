# CopyPasta for macOS

A macOS status bar application for cross-device clipboard sharing, equivalent to the Windows version.

## Features

- **Status Bar Integration**: Lives in the macOS status bar with a clipboard icon
- **Cross-Device Sync**: Share clipboard content between macOS and other devices
- **Multiple Content Types**: Supports text, rich text (RTF/HTML), and images
- **Real-Time Updates**: Long polling for instant clipboard synchronization
- **Native UI**: SwiftUI-based settings and about dialogs
- **Universal Binary**: Supports both Intel and Apple Silicon Macs
- **macOS Integration**: Native notifications and clipboard handling

## Requirements

- macOS 11.0 (Big Sur) or later
- Intel or Apple Silicon Mac

## Building

### Xcode (Recommended)
1. Open `CopyPasta.xcodeproj` in Xcode
2. Select your target architecture (Any Mac for universal binary)
3. Build and run (⌘+R)

### Command Line
```bash
cd macos
xcodebuild -project CopyPasta.xcodeproj -scheme CopyPasta -configuration Release -arch x86_64 -arch arm64 build
```

## Architecture

### Core Components

- **AppDelegate**: Main application controller and coordinator
- **StatusBarController**: Manages the status bar item and menu
- **ClipboardMonitor**: Monitors and manages system clipboard changes
- **CopyPastaClient**: HTTP client for server communication with long polling
- **Settings**: Persistent settings storage using UserDefaults
- **SettingsWindowController**: SwiftUI-based settings interface
- **AboutWindowController**: SwiftUI-based about dialog

### Status Bar Menu Structure
```
CopyPasta
─────────────
Settings...  ⌘,
About...
─────────────
Quit CopyPasta  ⌘Q
```

### Clipboard Support
- **Text**: Plain text content
- **Rich Text**: RTF and HTML content with formatting
- **Images**: PNG, JPEG, TIFF with base64 encoding for transmission

### Network Communication
- Uses URLSession with 35-second timeout for long polling
- Session-based authentication with cookie management
- Automatic retry logic with exponential backoff
- Client ID generation for multi-device filtering

## Configuration

### Settings (UserDefaults)
- `serverEndpoint`: Server URL (default: http://localhost:5000)
- `username`: Authentication username
- `password`: Authentication password  
- `showNotifications`: Enable/disable system notifications

### Debug Mode
When running in debug builds, default development settings are automatically applied:
- Server: http://localhost:5000
- Username: user
- Password: password

## Universal Binary Support

The project is configured to build universal binaries supporting both Intel and Apple Silicon:

- **ARCHS**: `$(ARCHS_STANDARD)` (arm64 + x86_64)
- **Deployment Target**: macOS 11.0
- **Swift Version**: 5.0

## Security & Sandboxing

The app includes entitlements for:
- App Sandbox (enabled)
- Network client access
- User-selected file access (read-only)

## API Compatibility

Compatible with the same server API as the Windows client:
- `POST /api/paste` - Upload clipboard content
- `GET /api/poll` - Long polling for changes
- `GET /api/clipboard` - Get current content
- `POST /login` - Authentication
- `GET /health` - Health check

## Logging

Uses unified logging (os_log) with categories:
- AppDelegate: Application lifecycle
- StatusBarController: Status bar operations
- ClipboardMonitor: Clipboard monitoring
- CopyPastaClient: Network operations
- Settings: Configuration changes

Console.app filter: `subsystem:com.benstaniford.copypasta`

## Development Notes

### SwiftUI Integration
- Settings and About windows use SwiftUI hosted in NSWindow
- ObservableObject pattern for reactive settings updates
- Native macOS controls and styling

### Async/Await
- Modern Swift concurrency for network operations
- Task-based long polling with proper cancellation
- Main actor isolation for UI updates

### Memory Management
- Proper cleanup of timers and tasks
- Weak references to prevent retain cycles
- Automatic session management