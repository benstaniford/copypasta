# CopyPasta Windows Installer

This directory contains the WiX installer project for the CopyPasta Windows client application.

## Building the Installer

### Prerequisites
- Visual Studio with C# development workload
- WiX Toolset v3.11 or newer (https://wixtoolset.org/releases/)
- .NET 6.0 SDK

### Local Build
```bash
# Build the solution (includes both app and installer)
dotnet build CopyPasta.sln --configuration Release

# Or build just the installer (after building the main app)
msbuild CopyPasta.Installer\CopyPasta.Installer.wixproj /p:Configuration=Release /p:Platform=x86
```

### GitHub Actions Build
The installer is automatically built and released when you create a git tag:

```bash
# Create and push a new version tag
git tag v1.0.0
git push origin v1.0.0
```

This will trigger the CI/CD pipeline which:
1. Updates version numbers in project files
2. Builds the C# application
3. Creates the MSI installer
4. Creates a GitHub release with the installer attached

## Installer Features

The installer includes:
- **Application Files**: Main executable and dependencies
- **Start Menu Shortcut**: Easy access to launch the application
- **Auto-start**: Automatically starts with Windows
- **PATH Environment**: Adds install directory to system PATH
- **Upgrade Support**: Properly handles upgrades and uninstalls
- **Process Management**: Kills existing instances before installation

## Installation Directory
Default installation path: `C:\Program Files\CopyPasta\`

## Uninstallation
The application can be uninstalled through:
- Windows Settings > Apps & features
- Control Panel > Programs and Features
- Running the MSI installer again and selecting "Remove"

## Customization

### Updating Version
Versions are automatically updated during CI/CD builds based on git tags. For manual builds, update:
- `Product.wxs`: `<Product Version="x.x.x.x" ...>`
- `../CopyPasta.csproj`: `<AssemblyVersion>` and `<FileVersion>`

### Modifying Install Behavior
Edit `Product.wxs` to customize:
- Installation directory structure
- Registry entries
- Custom actions
- UI components
- File components to include

### Adding Dependencies
If the main application requires additional DLL files, add them to the `ProductComponents` ComponentGroup in `Product.wxs`.