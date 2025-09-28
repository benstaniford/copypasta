import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    
    private var statusBarController: StatusBarController!
    private var clipboardMonitor: ClipboardMonitor!
    private var copyPastaClient: CopyPastaClient!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.log("AppDelegate", "Application starting up")
        
        // Initialize components on main thread
        DispatchQueue.main.async {
            self.setupApplication()
            self.startServices()
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
        Logger.log("AppDelegate", "Setting activation policy...")
        // Hide from Dock (we're a status bar only app)
        NSApp.setActivationPolicy(.accessory)
        
        Logger.log("AppDelegate", "Initializing status bar controller...")
        // Initialize status bar controller
        statusBarController = StatusBarController()
        statusBarController.delegate = self
        
        Logger.log("AppDelegate", "Initializing CopyPasta client...")
        // Initialize client
        copyPastaClient = CopyPastaClient()
        copyPastaClient.delegate = self
        
        Logger.log("AppDelegate", "Initializing clipboard monitor...")
        // Initialize clipboard monitor
        clipboardMonitor = ClipboardMonitor()
        clipboardMonitor.delegate = self
        
        Logger.log("AppDelegate", "Setup application complete")
    }
    
    private func startServices() {
        Logger.log("AppDelegate", "Loading settings...")
        // Load settings and start client if configured
        let settings = Settings.shared
        
        Logger.log("AppDelegate", "Settings configured: \(settings.isConfigured)")
        if settings.isConfigured {
            Logger.log("AppDelegate", "Updating client settings...")
            copyPastaClient.updateSettings(settings)
            Logger.log("AppDelegate", "Starting polling...")
            copyPastaClient.startPolling()
        }
        
        Logger.log("AppDelegate", "Starting clipboard monitoring...")
        // Start clipboard monitoring
        clipboardMonitor.startMonitoring()
        
        Logger.log("AppDelegate", "All services started")
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
        let settingsController = SettingsWindowController()
        settingsController.delegate = self
        settingsController.showWindow(nil)
        settingsController.window?.makeKeyAndOrderFront(nil)
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