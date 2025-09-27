@echo off
REM Batch script to build the CopyPasta Windows installer

setlocal enabledelayedexpansion

REM Default values
set VERSION=1.0.0.0
set CONFIGURATION=Release

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :start_build
if "%~1"=="-version" (
    set VERSION=%~2
    shift
    shift
    goto :parse_args
)
if "%~1"=="-config" (
    set CONFIGURATION=%~2
    shift
    shift
    goto :parse_args
)
shift
goto :parse_args

:start_build
echo Building CopyPasta Windows Installer
echo Version: %VERSION%
echo Configuration: %CONFIGURATION%
echo.

REM Check if WiX is installed
set WIX_PATH=C:\Program Files (x86)\WiX Toolset v3.11\bin
if not exist "%WIX_PATH%" (
    echo ERROR: WiX Toolset v3.11 not found. Please install WiX Toolset from https://wixtoolset.org/
    exit /b 1
)

REM Add WiX to PATH
set PATH=%PATH%;%WIX_PATH%

REM Check if dotnet is available
dotnet --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: .NET CLI not found. Please install .NET 6.0 SDK
    exit /b 1
)

REM Restore packages
echo Restoring NuGet packages...
dotnet restore CopyPasta.sln
if errorlevel 1 (
    echo ERROR: Failed to restore NuGet packages
    exit /b 1
)

REM Build the application
echo Building CopyPasta application...
dotnet build CopyPasta.csproj --configuration %CONFIGURATION% --no-restore
if errorlevel 1 (
    echo ERROR: Failed to build CopyPasta application
    exit /b 1
)

REM Build the installer
echo Building Windows installer...
set WixTargetsPath=%WIX_PATH%\wix.targets
msbuild "CopyPasta.Installer\CopyPasta.Installer.wixproj" /p:Configuration=%CONFIGURATION% /p:Platform=x86
if errorlevel 1 (
    echo ERROR: Failed to build installer
    exit /b 1
)

REM Check if installer was created
set INSTALLER_PATH=CopyPasta.Installer\bin\%CONFIGURATION%\CopyPasta-Setup.msi
if exist "%INSTALLER_PATH%" (
    echo.
    echo SUCCESS: Installer created successfully!
    echo Location: %INSTALLER_PATH%
    
    REM Get file size
    for %%I in ("%INSTALLER_PATH%") do set SIZE=%%~zI
    set /a SIZE_MB=!SIZE!/1048576
    echo Size: !SIZE_MB! MB
) else (
    echo ERROR: Installer file not found at expected location: %INSTALLER_PATH%
    exit /b 1
)

echo.
echo Build completed successfully!
pause