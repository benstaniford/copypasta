import Foundation
import os.log

class Logger {
    
    private static let subsystem = "com.benstaniford.copypasta"
    private static let defaultCategory = "default"
    
    static func log(_ category: String, _ message: String) {
        let logger = OSLog(subsystem: subsystem, category: category)
        os_log("%{public}@", log: logger, type: .info, message)
        print("[\(timestamp())] [\(category)] \(message)")
    }
    
    static func logError(_ category: String, _ message: String, _ error: Error) {
        let logger = OSLog(subsystem: subsystem, category: category)
        let errorMessage = "\(message): \(error.localizedDescription)"
        os_log("%{public}@", log: logger, type: .error, errorMessage)
        print("[\(timestamp())] [\(category)] ERROR: \(errorMessage)")
    }
    
    static func logNetwork(_ operation: String, _ url: String, _ status: String, _ details: String = "") {
        let category = "Network"
        let logger = OSLog(subsystem: subsystem, category: category)
        let message = "HTTP \(operation) \(url) - \(status)" + (details.isEmpty ? "" : " - \(details)")
        os_log("%{public}@", log: logger, type: .info, message)
        print("[\(timestamp())] [\(category)] \(message)")
    }
    
    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter.string(from: Date())
    }
}