import Cocoa
import UserNotifications

protocol StatusBarControllerDelegate: AnyObject {
    func statusBarControllerDidRequestOnlineClips()
    func statusBarControllerDidRequestSettings()
    func statusBarControllerDidRequestAbout()
    func statusBarControllerDidRequestQuit()
}

class StatusBarController: NSObject {
    
    weak var delegate: StatusBarControllerDelegate?
    
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    
    override init() {
        Logger.log("StatusBarController", "Initializing status bar controller...")
        
        // Create status item
        Logger.log("StatusBarController", "Creating status item...")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        
        super.init()
        
        Logger.log("StatusBarController", "Setting up status item...")
        setupStatusItem()
        Logger.log("StatusBarController", "Setting up menu...")
        setupMenu()
        Logger.log("StatusBarController", "Setting up notifications...")
        setupNotifications()
        
        Logger.log("StatusBarController", "Status bar controller initialized successfully")
    }
    
    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }
    
    private func setupStatusItem() {
        Logger.log("StatusBarController", "Setting up status item...")
        
        // Set the status bar icon
        if let button = statusItem.button {
            Logger.log("StatusBarController", "Status item button found, setting up icon...")
            // Use SF Symbols for a clean look
            if #available(macOS 11.0, *) {
                let image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CopyPasta")
                if image != nil {
                    button.image = image
                    Logger.log("StatusBarController", "SF Symbol icon set successfully")
                } else {
                    Logger.log("StatusBarController", "SF Symbol not found, using emoji fallback")
                    button.title = "📋"
                }
            } else {
                // Fallback for older macOS versions
                Logger.log("StatusBarController", "Using emoji fallback for older macOS")
                button.title = "📋"
            }
            button.imagePosition = .imageOnly
            button.toolTip = "CopyPasta - Cross-device clipboard sharing"
            
            Logger.log("StatusBarController", "Status item button configured")
        } else {
            Logger.log("StatusBarController", "ERROR: Could not get status item button!")
        }
        
        statusItem.menu = menu
        statusItem.isVisible = true
        
        Logger.log("StatusBarController", "Status item setup complete, visible: \(statusItem.isVisible)")
    }
    
    private func setupMenu() {
        menu.autoenablesItems = false
        
        // Title item
        let titleItem = NSMenuItem(title: "CopyPasta", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        let font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        let attributes = [NSAttributedString.Key.font: font]
        titleItem.attributedTitle = NSAttributedString(string: "CopyPasta", attributes: attributes)
        menu.addItem(titleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Clip History
        let onlineClipsItem = NSMenuItem(title: "Clip History...", action: #selector(onlineClipsClicked), keyEquivalent: "")
        onlineClipsItem.target = self
        onlineClipsItem.isEnabled = true
        menu.addItem(onlineClipsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Settings
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.isEnabled = true
        menu.addItem(settingsItem)
        
        // About
        let aboutItem = NSMenuItem(title: "About...", action: #selector(aboutClicked), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.isEnabled = true
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit CopyPasta", action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)
    }
    
    private func setupNotifications() {
        // Request notification permissions
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                Logger.logError("StatusBarController", "Notification permission error", error)
            } else {
                Logger.log("StatusBarController", "Notification permission granted: \(granted)")
            }
        }
    }
    
    @objc private func onlineClipsClicked() {
        delegate?.statusBarControllerDidRequestOnlineClips()
    }
    
    @objc private func settingsClicked() {
        delegate?.statusBarControllerDidRequestSettings()
    }
    
    @objc private func aboutClicked() {
        delegate?.statusBarControllerDidRequestAbout()
    }
    
    @objc private func quitClicked() {
        delegate?.statusBarControllerDidRequestQuit()
    }
    
    func showNotification(title: String, message: String) {
        guard Settings.shared.showNotifications else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = UNNotificationSound.default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Logger.logError("StatusBarController", "Failed to show notification", error)
            }
        }
    }
}