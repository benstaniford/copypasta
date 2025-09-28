import Cocoa
import Foundation

// Create a file to prove our code is running
let testFilePath = "/tmp/copypasta-debug.txt"
let debugMessage = "CopyPasta main.swift executed at \(Date())\n"
try? debugMessage.write(toFile: testFilePath, atomically: true, encoding: .utf8)

NSLog("=== CopyPasta main.swift STARTED ===")
print("=== CopyPasta main.swift STARTED ===")
fflush(stdout)

// Show an alert dialog to prove our code is running
DispatchQueue.main.async {
    let alert = NSAlert()
    alert.messageText = "CopyPasta Debug"
    alert.informativeText = "main.swift is executing!"
    alert.runModal()
}

do {
    NSLog("Creating NSApplication.shared")
    let app = NSApplication.shared
    
    NSLog("Creating AppDelegate")
    let delegate = AppDelegate()
    
    NSLog("Setting app delegate")
    app.delegate = delegate
    
    NSLog("About to call app.run()")
    app.run()
} catch {
    NSLog("ERROR in main.swift: \(error)")
    print("ERROR in main.swift: \(error)")
}