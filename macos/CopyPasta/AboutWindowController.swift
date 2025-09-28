import Cocoa
import SwiftUI

class AboutWindowController: NSWindowController {
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 280),
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
        
        window.title = "About CopyPasta"
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .normal
    }
    
    private func setupContent() {
        guard let window = window else { return }
        
        let aboutView = AboutView {
            self.close()
        }
        
        let hostingView = NSHostingView(rootView: aboutView)
        window.contentView = hostingView
    }
}

struct AboutView: View {
    let onClose: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // App Icon (using SF Symbol as placeholder)
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
            
            // App Name
            Text("CopyPasta")
                .font(.title)
                .fontWeight(.bold)
            
            // Version
            Text("Version \(getVersionString())")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Copyright
            Text("© 2024 Ben Staniford")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // License
            Text("Licensed under the GNU General Public License v2.0")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 8) {
                // License Link
                Button("View License") {
                    if let url = URL(string: "https://www.gnu.org/licenses/old-licenses/gpl-2.0.html") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(LinkButtonStyle())
                
                // GitHub Link
                Button("See Latest Version on GitHub") {
                    if let url = URL(string: "https://github.com/benstaniford/copypasta") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(LinkButtonStyle())
            }
            
            Spacer()
            
            Button("OK") {
                onClose()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func getVersionString() -> String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return version
        }
        return "Unknown"
    }
}

struct LinkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.blue)
            .font(.caption)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .offset(y: 1),
                alignment: .bottom
            )
    }
}