import Cocoa
import UserNotifications

protocol StatusBarControllerDelegate: AnyObject {
    func statusBarControllerDidRequestSettings()
    func statusBarControllerDidRequestAbout()
    func statusBarControllerDidRequestQuit()
}

class StatusBarController: NSObject {
    
    weak var delegate: StatusBarControllerDelegate?
    
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    
    override init() {
        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        
        super.init()
        
        setupStatusItem()
        setupMenu()
        setupNotifications()
    }
    
    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
    }
    
    private func setupStatusItem() {
        // Set the status bar icon
        if let button = statusItem.button {
            // Use SF Symbols for a clean look
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "CopyPasta")
            } else {
                // Fallback for older macOS versions
                button.title = "📋"
            }
            button.imagePosition = .imageOnly
            button.toolTip = "CopyPasta - Cross-device clipboard sharing"
        }
        
        statusItem.menu = menu
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