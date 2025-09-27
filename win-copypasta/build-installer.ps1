# PowerShell script to build the CopyPasta Windows installer
param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "1.0.0.0",
    
    [Parameter(Mandatory=$false)]
    [string]$Configuration = "Release",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipBuild
)

Write-Host "Building CopyPasta Windows Installer" -ForegroundColor Green
Write-Host "Version: $Version" -ForegroundColor Yellow
Write-Host "Configuration: $Configuration" -ForegroundColor Yellow

# Check if WiX is installed
$wixPath = "C:\Program Files (x86)\WiX Toolset v3.11\bin"
if (-not (Test-Path $wixPath)) {
    Write-Error "WiX Toolset v3.11 not found. Please install WiX Toolset from https://wixtoolset.org/"
    exit 1
}

# Add WiX to PATH if not already there
if ($env:PATH -notlike "*$wixPath*") {
    $env:PATH += ";$wixPath"
}

try {
    # Update version in project files
    Write-Host "Updating version numbers..." -ForegroundColor Cyan
    
    # Update .csproj version
    $csprojPath = "CopyPasta.csproj"
    if (Test-Path $csprojPath) {
        $content = Get-Content $csprojPath -Raw
        $content = $content -replace "<AssemblyVersion>.*</AssemblyVersion>", "<AssemblyVersion>$Version</AssemblyVersion>"
        $content = $content -replace "<FileVersion>.*</FileVersion>", "<FileVersion>$Version</FileVersion>"
        Set-Content $csprojPath $content
        Write-Host "Updated $csprojPath" -ForegroundColor Gray
    }
    
    # Update WiX version
    $wixPath = "CopyPasta.Installer\Product.wxs"
    if (Test-Path $wixPath) {
        $content = Get-Content $wixPath -Raw
        $content = $content -replace 'Version="[^"]*"', "Version=`"$Version`""
        Set-Content $wixPath $content
        Write-Host "Updated $wixPath" -ForegroundColor Gray
    }

    if (-not $SkipBuild) {
        # Restore NuGet packages
        Write-Host "Restoring NuGet packages..." -ForegroundColor Cyan
        dotnet restore CopyPasta.sln
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to restore NuGet packages"
        }

        # Build the main application
        Write-Host "Building CopyPasta application..." -ForegroundColor Cyan
        dotnet build CopyPasta.csproj --configuration $Configuration --no-restore
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to build CopyPasta application"
        }
    }

    # Build the installer
    Write-Host "Building Windows installer..." -ForegroundColor Cyan
    
    # Set WiX environment variables
    $env:WixTargetsPath = "$wixPath\wix.targets"
    
    # Build installer using MSBuild
    msbuild "CopyPasta.Installer\CopyPasta.Installer.wixproj" /p:Configuration=$Configuration /p:Platform=x86 /p:OutputPath="bin\$Configuration\"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to build installer"
    }

    # Check if installer was created
    $installerPath = "CopyPasta.Installer\bin\$Configuration\CopyPasta-Setup.msi"
    if (Test-Path $installerPath) {
        Write-Host "Installer created successfully!" -ForegroundColor Green
        Write-Host "Location: $installerPath" -ForegroundColor Yellow
        
        # Get file size
        $fileSize = (Get-Item $installerPath).Length
        $fileSizeMB = [math]::Round($fileSize / 1MB, 2)
        Write-Host "Size: $fileSizeMB MB" -ForegroundColor Gray
        
        # Optionally rename with version
        if ($Version -ne "1.0.0.0") {
            $versionedName = "CopyPasta-Setup-v$Version.msi"
            $versionedPath = "CopyPasta.Installer\bin\$Configuration\$versionedName"
            Copy-Item $installerPath $versionedPath
            Write-Host "Versioned installer: $versionedPath" -ForegroundColor Yellow
        }
    } else {
        throw "Installer file not found at expected location: $installerPath"
    }

    Write-Host "Build completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Error "Build failed: $($_.Exception.Message)"
    exit 1
}

# Build portable version
Write-Host "Building portable version..." -ForegroundColor Cyan
try {
    $portableDir = "bin\Portable"
    if (Test-Path $portableDir) {
        Remove-Item $portableDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $portableDir -Force | Out-Null
    
    dotnet publish CopyPasta.csproj --configuration $Configuration --runtime win-x64 --self-contained true -p:PublishSingleFile=true --output $portableDir
    if ($LASTEXITCODE -eq 0) {
        $zipName = "CopyPasta-Portable-v$Version.zip"
        $zipPath = "bin\$Configuration\$zipName"
        Compress-Archive -Path "$portableDir\CopyPasta.exe" -DestinationPath $zipPath -Force
        Write-Host "Portable version created: $zipPath" -ForegroundColor Green
    }
} catch {
    Write-Warning "Failed to create portable version: $($_.Exception.Message)"
}

Write-Host "All builds completed!" -ForegroundColor Green