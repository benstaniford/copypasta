import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    
    override init() {
        super.init()
        print("CopyPasta: AppDelegate init called")
        NSLog("CopyPasta: AppDelegate init called with NSLog")
        Logger.log("AppDelegate", "AppDelegate initialized")
    }
    
    private var statusBarController: StatusBarController!
    private var clipboardMonitor: ClipboardMonitor!
    private var copyPastaClient: CopyPastaClient!
    private var settingsController: SettingsWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("CopyPasta: applicationDidFinishLaunching called")
        NSLog("CopyPasta: applicationDidFinishLaunching called with NSLog")
        Logger.log("AppDelegate", "Application starting up")
        
        // Initialize components on main thread
        DispatchQueue.main.async {
            print("CopyPasta: Starting setup on main thread")
            NSLog("CopyPasta: Starting setup on main thread")
            self.setupApplication()
            print("CopyPasta: setupApplication completed, about to call startServices")
            NSLog("CopyPasta: setupApplication completed, about to call startServices")
            self.startServices()
            print("CopyPasta: startServices completed")
            NSLog("CopyPasta: startServices completed")
            Logger.log("AppDelegate", "Application startup complete")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Logger.log("AppDelegate", "Application terminating")
        cleanup()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Don't quit when last window closes - we're a status bar app
        return false
    }
    
    private func setupApplication() {
        print("CopyPasta: setupApplication started")
        NSLog("CopyPasta: setupApplication started")
        Logger.log("AppDelegate", "Setting activation policy...")
        
        // Hide from Dock (we're a status bar only app)
        NSApp.setActivationPolicy(.accessory)
        print("CopyPasta: Set activation policy to accessory")
        
        Logger.log("AppDelegate", "Initializing status bar controller...")
        // Initialize status bar controller
        print("CopyPasta: About to create StatusBarController")
        statusBarController = StatusBarController()
        print("CopyPasta: StatusBarController created, setting delegate")
        statusBarController.delegate = self
        
        Logger.log("AppDelegate", "Initializing CopyPasta client...")
        // Initialize client
        print("CopyPasta: About to create CopyPastaClient")
        NSLog("CopyPasta: About to create CopyPastaClient")
        copyPastaClient = CopyPastaClient()
        print("CopyPasta: CopyPastaClient created, setting delegate")
        NSLog("CopyPasta: CopyPastaClient created, setting delegate")
        copyPastaClient.delegate = self
        
        Logger.log("AppDelegate", "Initializing clipboard monitor...")
        // Initialize clipboard monitor
        print("CopyPasta: About to create ClipboardMonitor")
        NSLog("CopyPasta: About to create ClipboardMonitor")
        clipboardMonitor = ClipboardMonitor()
        print("CopyPasta: ClipboardMonitor created, setting delegate")
        NSLog("CopyPasta: ClipboardMonitor created, setting delegate")
        clipboardMonitor.delegate = self
        
        print("CopyPasta: All components created successfully")
        Logger.log("AppDelegate", "Setup application complete")
    }
    
    private func startServices() {
        print("CopyPasta: startServices() called")
        NSLog("CopyPasta: startServices() called")
        Logger.log("AppDelegate", "Loading settings...")
        
        // Load settings and start client if configured
        print("CopyPasta: About to access Settings.shared")
        NSLog("CopyPasta: About to access Settings.shared")
        let settings = Settings.shared
        print("CopyPasta: Settings.shared accessed successfully")
        NSLog("CopyPasta: Settings.shared accessed successfully")
        
        Logger.log("AppDelegate", "Settings configured: \(settings.isConfigured)")
        if settings.isConfigured {
            Logger.log("AppDelegate", "Updating client settings...")
            copyPastaClient.updateSettings(settings)
            Logger.log("AppDelegate", "Starting polling...")
            copyPastaClient.startPolling()
        }
        
        Logger.log("AppDelegate", "Starting clipboard monitoring...")
        // Start clipboard monitoring - it works regardless of accessibility permission status
        clipboardMonitor.startMonitoring()
        
        // Check accessibility permissions for informational purposes
        let hasPermissions = AccessibilityPermissionManager.shared.hasAccessibilityPermissions()
        Logger.log("AppDelegate", "Accessibility permissions status: \(hasPermissions)")
        
        if !hasPermissions {
            Logger.log("AppDelegate", "Note: Accessibility permissions not detected, but clipboard monitoring works anyway")
        }
        
        Logger.log("AppDelegate", "All services started")
    }
    
    private func cleanup() {
        clipboardMonitor?.stopMonitoring()
        copyPastaClient?.stopPolling()
    }
}

// MARK: - StatusBarController Delegate
extension AppDelegate: StatusBarControllerDelegate {
    func statusBarControllerDidRequestOnlineClips() {
        Logger.log("AppDelegate", "Clip History requested")
        openOnlineClips()
    }
    
    func statusBarControllerDidRequestSettings() {
        Logger.log("AppDelegate", "Settings requested")
        showSettings()
    }
    
    func statusBarControllerDidRequestAbout() {
        Logger.log("AppDelegate", "About requested")
        showAbout()
    }
    
    func statusBarControllerDidRequestQuit() {
        Logger.log("AppDelegate", "Quit requested")
        NSApplication.shared.terminate(nil)
    }
    
    private func showSettings() {
        if settingsController == nil {
            settingsController = SettingsWindowController()
            settingsController?.delegate = self
        }
        
        settingsController?.showWindow(nil)
        settingsController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func openOnlineClips() {
        let settings = Settings.shared
        
        if settings.isConfigured {
            let url = URL(string: settings.serverEndpoint)
            if let url = url {
                Logger.log("AppDelegate", "Opening web interface at: \(settings.serverEndpoint)")
                NSWorkspace.shared.open(url)
            } else {
                Logger.log("AppDelegate", "Invalid server endpoint URL: \(settings.serverEndpoint)")
                showAlert(title: "Invalid URL", message: "The server endpoint URL is not valid. Please check your settings.")
            }
        } else {
            Logger.log("AppDelegate", "Settings not configured, showing settings first")
            showAlert(title: "Configuration Required", message: "Please configure the server settings first.", showSettings: true)
        }
    }
    
    private func showAlert(title: String, message: String, showSettings: Bool = false) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        if showSettings {
            alert.addButton(withTitle: "Settings...")
        }
        
        let response = alert.runModal()
        
        if showSettings && response == .alertSecondButtonReturn {
            self.showSettings()
        }
    }
    
    private func showAbout() {
        let aboutController = AboutWindowController()
        aboutController.showWindow(nil)
        aboutController.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - SettingsWindowController Delegate
extension AppDelegate: SettingsWindowControllerDelegate {
    func settingsDidChange(_ settings: Settings) {
        Logger.log("AppDelegate", "Settings updated")
        copyPastaClient.updateSettings(settings)
        
        if settings.isConfigured {
            copyPastaClient.startPolling()
        } else {
            copyPastaClient.stopPolling()
        }
        
        // Clear the settings controller reference when done
        settingsController = nil
    }
    
    func testConnection() async -> Bool {
        Logger.log("AppDelegate", "Testing connection using main CopyPastaClient")
        // Update the main client with current settings first
        copyPastaClient.updateSettings(Settings.shared)
        return await copyPastaClient.testConnection()
    }
}

// MARK: - ClipboardMonitor Delegate
extension AppDelegate: ClipboardMonitorDelegate {
    func clipboardDidChange(content: String, type: ClipboardContentType, filename: String?) {
        Logger.log("AppDelegate", "Clipboard changed: \(type), length: \(content.count), filename: \(filename ?? "none")")

        if Settings.shared.isConfigured {
            Task {
                do {
                    try await copyPastaClient.uploadClipboardContent(content: content, type: type, filename: filename)
                    if Settings.shared.showNotifications {
                        let typeLabel = type == .file ? "File" : "Content"
                        statusBarController.showNotification(title: "CopyPasta", message: "\(typeLabel) uploaded successfully")
                    }
                } catch {
                    Logger.logError("AppDelegate", "Failed to upload clipboard content", error)
                    if Settings.shared.showNotifications {
                        statusBarController.showNotification(title: "CopyPasta", message: "Upload failed: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
}

// MARK: - CopyPastaClient Delegate
extension AppDelegate: CopyPastaClientDelegate {
    func clipboardChangedOnServer(content: String, type: ClipboardContentType, filename: String?) {
        Logger.log("AppDelegate", "Server clipboard changed: \(type), length: \(content.count), filename: \(filename ?? "none")")

        DispatchQueue.main.async {
            self.clipboardMonitor.setClipboardContent(content: content, type: type, filename: filename)
            if Settings.shared.showNotifications {
                let typeLabel = type == .file ? "File" : "Clipboard"
                self.statusBarController.showNotification(title: "CopyPasta", message: "\(typeLabel) updated from server")
            }
        }
    }
}