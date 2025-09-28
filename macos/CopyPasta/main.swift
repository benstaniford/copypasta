import Cocoa
import Foundation

// Create a file to prove our code is running
let testFilePath = "/tmp/copypasta-debug.txt"
let debugMessage = "CopyPasta main.swift executed at \(Date())\n"
try? debugMessage.write(toFile: testFilePath, atomically: true, encoding: .utf8)

NSLog("=== CopyPasta main.swift STARTED ===")
print("=== CopyPasta main.swift STARTED ===")

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

NSLog("About to call app.run()")
app.run()