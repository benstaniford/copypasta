import Cocoa
import ApplicationServices

class AccessibilityPermissionManager {
    
    static let shared = AccessibilityPermissionManager()
    
    private init() {}
    
    /// Check if accessibility permissions are granted
    func hasAccessibilityPermissions() -> Bool {
        let result = AXIsProcessTrusted()
        Logger.log("AccessibilityPermissionManager", "AXIsProcessTrusted() returned: \(result)")
        
        // Also check with options to see if that makes a difference
        let resultWithOptions = AXIsProcessTrustedWithOptions(nil)
        Logger.log("AccessibilityPermissionManager", "AXIsProcessTrustedWithOptions(nil) returned: \(resultWithOptions)")
        
        return result
    }
    
    /// Request accessibility permissions and show dialog if needed
    func requestAccessibilityPermissions() {
        if hasAccessibilityPermissions() {
            Logger.log("AccessibilityPermissionManager", "Accessibility permissions already granted")
            return
        }
        
        Logger.log("AccessibilityPermissionManager", "Accessibility permissions not granted, showing dialog")
        showPermissionDialog()
    }
    
    /// Check if accessibility permissions are granted for a specific process
    func requestAccessibilityPermissionsWithPrompt() -> Bool {
        let trusted = AXIsProcessTrustedWithOptions([
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary)
        
        Logger.log("AccessibilityPermissionManager", "Accessibility permissions check result: \(trusted)")
        return trusted
    }
    
    private func showPermissionDialog() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = """
            CopyPasta needs accessibility permissions to monitor and manage your clipboard across devices.
            
            To grant permissions:
            1. Click "Open System Settings" below
            2. Find "CopyPasta" in the list
            3. Toggle the switch to enable it
            4. Restart CopyPasta
            """
            alert.alertStyle = .informational
            alert.icon = NSImage(systemSymbolName: "exclamationmark.shield", accessibilityDescription: "Security")
            
            // Add buttons
            let openSettingsButton = alert.addButton(withTitle: "Open System Settings")
            let laterButton = alert.addButton(withTitle: "Later")
            let quitButton = alert.addButton(withTitle: "Quit CopyPasta")
            
            // Style the primary button
            openSettingsButton.keyEquivalent = "\r"
            
            // Show the alert
            NSApp.activate(ignoringOtherApps: true)
            let response = alert.runModal()
            
            switch response {
            case .alertFirstButtonReturn: // Open System Settings
                self.openSystemSettings()
                
            case .alertSecondButtonReturn: // Later
                Logger.log("AccessibilityPermissionManager", "User chose to grant permissions later")
                
            case .alertThirdButtonReturn: // Quit
                Logger.log("AccessibilityPermissionManager", "User chose to quit")
                NSApplication.shared.terminate(nil)
                
            default:
                break
            }
        }
    }
    
    private func openSystemSettings() {
        Logger.log("AccessibilityPermissionManager", "Opening System Settings")
        
        // Try different URLs based on macOS version
        let settingsURLs = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility", // macOS 13+
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility", // macOS 12
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"  // Fallback
        ]
        
        var opened = false
        for urlString in settingsURLs {
            if let url = URL(string: urlString) {
                opened = NSWorkspace.shared.open(url)
                if opened {
                    Logger.log("AccessibilityPermissionManager", "Opened System Settings with URL: \(urlString)")
                    break
                }
            }
        }
        
        if !opened {
            // Fallback: open System Settings main page
            if let url = URL(string: "x-apple.systempreferences:") {
                opened = NSWorkspace.shared.open(url)
                Logger.log("AccessibilityPermissionManager", "Opened System Settings main page as fallback")
            }
        }
        
        if !opened {
            // Last resort: show instructions
            let fallbackAlert = NSAlert()
            fallbackAlert.messageText = "Manual Setup Required"
            fallbackAlert.informativeText = """
            Please manually open System Settings and navigate to:
            
            Privacy & Security → Accessibility
            
            Then find "CopyPasta" and enable it.
            """
            fallbackAlert.addButton(withTitle: "OK")
            fallbackAlert.runModal()
        }
    }
    
    /// Check permissions periodically and notify when granted
    func startPeriodicCheck(onGranted: @escaping () -> Void) {
        if hasAccessibilityPermissions() {
            onGranted()
            return
        }
        
        Logger.log("AccessibilityPermissionManager", "Starting periodic permission check")
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            if self.hasAccessibilityPermissions() {
                Logger.log("AccessibilityPermissionManager", "Accessibility permissions granted!")
                timer.invalidate()
                DispatchQueue.main.async {
                    onGranted()
                }
            }
        }
    }
}