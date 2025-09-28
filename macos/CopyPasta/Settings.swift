import Foundation

class Settings: ObservableObject {
    
    static let shared = Settings()
    
    @Published var serverEndpoint: String {
        didSet { save() }
    }
    
    @Published var username: String {
        didSet { save() }
    }
    
    @Published var password: String {
        didSet { save() }
    }
    
    @Published var showNotifications: Bool {
        didSet { save() }
    }
    
    var isConfigured: Bool {
        return !serverEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private let userDefaults = UserDefaults.standard
    
    private init() {
        Logger.log("Settings", "Initializing settings...")
        
        serverEndpoint = userDefaults.string(forKey: "serverEndpoint") ?? "http://localhost:5000"
        username = userDefaults.string(forKey: "username") ?? ""
        password = userDefaults.string(forKey: "password") ?? ""
        showNotifications = userDefaults.object(forKey: "showNotifications") as? Bool ?? true
        
        Logger.log("Settings", "Loaded settings - endpoint: \(serverEndpoint), username: \(username.isEmpty ? "empty" : "set")")
        
        // Override settings if running in debug mode
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == nil {
            Logger.log("Settings", "Debug mode detected - using development settings")
            serverEndpoint = "http://localhost:5000"
            username = "user"
            password = "password"
        }
        #endif
        
        Logger.log("Settings", "Settings initialization complete")
    }
    
    private func save() {
        userDefaults.set(serverEndpoint, forKey: "serverEndpoint")
        userDefaults.set(username, forKey: "username")
        userDefaults.set(password, forKey: "password")
        userDefaults.set(showNotifications, forKey: "showNotifications")
        
        Logger.log("Settings", "Settings saved")
    }
    
    func reset() {
        serverEndpoint = "http://localhost:5000"
        username = ""
        password = ""
        showNotifications = true
        Logger.log("Settings", "Settings reset to defaults")
    }
}