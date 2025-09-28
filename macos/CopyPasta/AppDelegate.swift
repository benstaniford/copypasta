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
        
        Logger.log("AppDelegate", "Checking accessibility permissions...")
        // Check accessibility permissions and start clipboard monitoring accordingly
        let hasPermissions = AccessibilityPermissionManager.shared.hasAccessibilityPermissions()
        Logger.log("AppDelegate", "Accessibility permissions status: \(hasPermissions)")
        
        if hasPermissions {
            Logger.log("AppDelegate", "Accessibility permissions already granted, starting clipboard monitoring...")
            clipboardMonitor.startMonitoring()
            Logger.log("AppDelegate", "All services started")
        } else {
            Logger.log("AppDelegate", "Accessibility permissions not granted, setting up permission monitoring...")
            
            // Since you've confirmed permissions are granted in System Settings, let's try starting anyway
            Logger.log("AppDelegate", "Attempting to start clipboard monitoring despite permission check...")
            clipboardMonitor.startMonitoring()
            
            // Start periodic check for when permissions are granted
            AccessibilityPermissionManager.shared.startPeriodicCheck { [weak self] in
                Logger.log("AppDelegate", "Accessibility permissions granted, starting clipboard monitoring...")
                self?.clipboardMonitor.startMonitoring()
                Logger.log("AppDelegate", "All services started")
            }
            
            // Request permissions (will show dialog if needed)
            AccessibilityPermissionManager.shared.requestAccessibilityPermissions()
        }
    }
    
    private func cleanup() {
        clipboardMonitor?.stopMonitoring()
        copyPastaClient?.stopPolling()
    }
}

// MARK: - StatusBarController Delegate
extension AppDelegate: StatusBarControllerDelegate {
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
    func clipboardDidChange(content: String, type: ClipboardContentType) {
        Logger.log("AppDelegate", "Clipboard changed: \(type), length: \(content.count)")
        
        if Settings.shared.isConfigured {
            Task {
                do {
                    try await copyPastaClient.uploadClipboardContent(content: content, type: type)
                    if Settings.shared.showNotifications {
                        statusBarController.showNotification(title: "CopyPasta", message: "Content uploaded successfully")
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
    func clipboardChangedOnServer(content: String, type: ClipboardContentType) {
        Logger.log("AppDelegate", "Server clipboard changed: \(type), length: \(content.count)")
        
        DispatchQueue.main.async {
            self.clipboardMonitor.setClipboardContent(content: content, type: type)
            if Settings.shared.showNotifications {
                self.statusBarController.showNotification(title: "CopyPasta", message: "Clipboard updated from server")
            }
        }
    }
}