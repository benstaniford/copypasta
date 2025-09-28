import Cocoa
import SwiftUI

protocol SettingsWindowControllerDelegate: AnyObject {
    func settingsDidChange(_ settings: Settings)
}

class SettingsWindowController: NSWindowController {
    
    weak var delegate: SettingsWindowControllerDelegate?
    
    private let settings = Settings.shared
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.init(window: window)
        
        setupWindow()
        setupContent()
    }
    
    private func setupWindow() {
        guard let window = window else { return }
        
        window.title = "CopyPasta Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .normal
    }
    
    private func setupContent() {
        guard let window = window else { return }
        
        let settingsView = SettingsView(
            settings: settings,
            onTestConnection: { [weak self] in
                return await self?.testConnection() ?? false
            },
            onSave: { [weak self] in
                self?.saveSettings()
            },
            onCancel: { [weak self] in
                self?.close()
            }
        )
        
        let hostingView = NSHostingView(rootView: settingsView)
        window.contentView = hostingView
    }
    
    private func testConnection() async -> Bool {
        let client = CopyPastaClient()
        client.updateSettings(settings)
        return await client.testConnection()
    }
    
    private func saveSettings() {
        delegate?.settingsDidChange(settings)
        close()
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    
    let onTestConnection: () async -> Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    @State private var isTestingConnection = false
    @State private var connectionTestResult: String = ""
    @State private var connectionTestColor: Color = .primary
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Server Endpoint:")
                        .font(.system(size: 13, weight: .medium))
                    TextField("http://localhost:5000", text: $settings.serverEndpoint)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username:")
                        .font(.system(size: 13, weight: .medium))
                    TextField("Username", text: $settings.username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password:")
                        .font(.system(size: 13, weight: .medium))
                    SecureField("Password", text: $settings.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Toggle("Show notifications", isOn: $settings.showNotifications)
                    .font(.system(size: 13))
                
                HStack {
                    Button("Test Connection") {
                        Task {
                            await testConnectionAction()
                        }
                    }
                    .disabled(isTestingConnection || !settings.isConfigured)
                    
                    if isTestingConnection {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                    
                    Text(connectionTestResult)
                        .font(.system(size: 12))
                        .foregroundColor(connectionTestColor)
                }
            }
            
            Spacer()
            
            HStack {
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape)
                
                Button("Save") {
                    onSave()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!settings.isConfigured)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func testConnectionAction() async {
        isTestingConnection = true
        connectionTestResult = "Testing..."
        connectionTestColor = .blue
        
        let success = await onTestConnection()
        
        isTestingConnection = false
        if success {
            connectionTestResult = "Connection successful!"
            connectionTestColor = .green
        } else {
            connectionTestResult = "Connection failed!"
            connectionTestColor = .red
        }
        
        // Clear the message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            connectionTestResult = ""
        }
    }
}