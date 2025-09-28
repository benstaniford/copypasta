import Foundation

protocol CopyPastaClientDelegate: AnyObject {
    func clipboardChangedOnServer(content: String, type: ClipboardContentType)
}

class CopyPastaClient {
    
    weak var delegate: CopyPastaClientDelegate?
    
    private var settings: Settings?
    private var sessionCookie: String?
    private var lastKnownVersion = 0
    private var pollTask: Task<Void, Never>?
    private let clientId: String
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 35
        config.timeoutIntervalForResource = 35
        return URLSession(configuration: config)
    }()
    
    init() {
        self.clientId = CopyPastaClient.generateClientId()
        Logger.log("CopyPastaClient", "Initialized with client ID: \(clientId)")
    }
    
    deinit {
        stopPolling()
    }
    
    func updateSettings(_ settings: Settings) {
        Logger.log("CopyPastaClient", "Settings updated - Endpoint: \(settings.serverEndpoint)")
        self.settings = settings
        sessionCookie = nil // Reset session when settings change
        stopPolling()
    }
    
    func startPolling() {
        guard let settings = settings, settings.isConfigured else {
            Logger.log("CopyPastaClient", "Cannot start polling - not configured")
            return
        }
        
        Logger.log("CopyPastaClient", "Starting polling")
        stopPolling()
        
        pollTask = Task {
            await pollForChanges()
        }
    }
    
    func stopPolling() {
        Logger.log("CopyPastaClient", "Stopping polling")
        pollTask?.cancel()
        pollTask = nil
    }
    
    func testConnection() async -> Bool {
        guard let settings = settings else { 
            Logger.log("CopyPastaClient", "testConnection failed: no settings")
            return false 
        }
        
        guard let url = URL(string: "\(settings.serverEndpoint)/health") else {
            Logger.log("CopyPastaClient", "testConnection failed: invalid URL \(settings.serverEndpoint)/health")
            return false
        }
        
        Logger.logNetwork("GET", url.absoluteString, "Starting")
        
        do {
            let (data, response) = try await urlSession.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                Logger.logNetwork("GET", url.absoluteString, "Response", "Status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        Logger.logNetwork("GET", url.absoluteString, "Success", "Response: \(responseString)")
                    }
                    return true
                } else {
                    Logger.logNetwork("GET", url.absoluteString, "Failed", "HTTP \(httpResponse.statusCode)")
                    return false
                }
            } else {
                Logger.logNetwork("GET", url.absoluteString, "Failed", "No HTTP response")
                return false
            }
        } catch {
            Logger.logNetwork("GET", url.absoluteString, "Exception", error.localizedDescription)
            Logger.log("CopyPastaClient", "testConnection error details: \(error)")
            return false
        }
    }
    
    func uploadClipboardContent(content: String, type: ClipboardContentType) async throws {
        guard let settings = settings, settings.isConfigured else {
            throw CopyPastaError.notConfigured
        }
        
        Logger.logNetwork("Upload", "UploadClipboardContent", "Starting", "Type: \(type), Size: \(content.count) bytes")
        
        try await ensureAuthenticated()
        
        let apiContentType: String
        switch type {
        case .text:
            apiContentType = "text"
        case .richText:
            apiContentType = "rich"
        case .image:
            apiContentType = "image"
        }
        
        let payload: [String: Any] = [
            "type": apiContentType,
            "content": content,
            "client_id": clientId
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        
        let url = URL(string: "\(settings.serverEndpoint)/api/paste")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        if let sessionCookie = sessionCookie {
            request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
        }
        
        let (_, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 {
                Logger.logNetwork("Upload", url.absoluteString, "Success", "Content uploaded successfully")
            } else {
                Logger.logNetwork("Upload", url.absoluteString, "Failed", "Status: \(httpResponse.statusCode)")
                throw CopyPastaError.httpError(httpResponse.statusCode)
            }
        }
    }
    
    private func ensureAuthenticated() async throws {
        guard let settings = settings else { throw CopyPastaError.notConfigured }
        
        if sessionCookie != nil {
            Logger.logNetwork("Authentication", "EnsureAuthenticated", "Skipped", "Already authenticated")
            return
        }
        
        Logger.logNetwork("Authentication", "EnsureAuthenticated", "Starting", "User: \(settings.username)")
        
        let loginData = "username=\(settings.username)&password=\(settings.password)"
        let loginDataEncoded = loginData.data(using: .utf8)!
        
        let url = URL(string: "\(settings.serverEndpoint)/login")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = loginDataEncoded
        
        let (_, response) = try await urlSession.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 200 || httpResponse.statusCode == 302 {
                // Extract session cookie
                if let cookies = httpResponse.allHeaderFields["Set-Cookie"] as? String {
                    if let sessionCookie = extractSessionCookie(from: cookies) {
                        self.sessionCookie = sessionCookie
                        Logger.logNetwork("Authentication", url.absoluteString, "Success", "Session cookie acquired")
                        return
                    }
                }
                Logger.logNetwork("Authentication", url.absoluteString, "Failed", "No session cookie received")
                throw CopyPastaError.authenticationFailed
            } else {
                Logger.logNetwork("Authentication", url.absoluteString, "Failed", "Status: \(httpResponse.statusCode)")
                throw CopyPastaError.authenticationFailed
            }
        }
    }
    
    private func extractSessionCookie(from cookieHeader: String) -> String? {
        let cookies = cookieHeader.components(separatedBy: ",")
        for cookie in cookies {
            let parts = cookie.trimmingCharacters(in: .whitespaces).components(separatedBy: ";")
            if let firstPart = parts.first, firstPart.hasPrefix("session=") {
                return firstPart
            }
        }
        return nil
    }
    
    private func pollForChanges() async {
        guard let settings = settings, settings.isConfigured else { return }
        
        while !Task.isCancelled {
            do {
                try await ensureAuthenticated()
                
                let url = URL(string: "\(settings.serverEndpoint)/api/poll?version=\(lastKnownVersion)&timeout=30&client_id=\(clientId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? clientId)")!
                var request = URLRequest(url: url)
                
                if let sessionCookie = sessionCookie {
                    request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")
                }
                
                let (data, response) = try await urlSession.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    if let pollResponse = try? JSONDecoder().decode(PollResponse.self, from: data) {
                        if pollResponse.version > 0 {
                            lastKnownVersion = pollResponse.version
                        }
                        
                        if pollResponse.status == "success", let clipboardData = pollResponse.data {
                            Logger.logNetwork("LongPoll", url.absoluteString, "NewData", "Version: \(pollResponse.version), Type: \(clipboardData.contentType)")
                            
                            let contentType: ClipboardContentType
                            switch clipboardData.contentType {
                            case "text":
                                contentType = .text
                            case "rich":
                                contentType = .richText
                            case "image":
                                contentType = .image
                            default:
                                contentType = .text
                            }
                            
                            delegate?.clipboardChangedOnServer(content: clipboardData.content, type: contentType)
                        } else if pollResponse.status == "timeout" {
                            Logger.logNetwork("LongPoll", url.absoluteString, "Timeout", "Version: \(pollResponse.version)")
                        }
                    }
                } else {
                    Logger.logNetwork("LongPoll", url.absoluteString, "Failed", "Status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                }
            } catch {
                if !Task.isCancelled {
                    Logger.logError("CopyPastaClient", "Polling error", error)
                    try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                }
            }
        }
    }
    
    private static func generateClientId() -> String {
        let hostName = Host.current().name ?? "unknown"
        let userName = NSUserName()
        let randomPart = String(UUID().uuidString.prefix(8))
        return "\(hostName)-\(userName)-\(randomPart)"
    }
}

// MARK: - Data Models
struct PollResponse: Codable {
    let status: String
    let data: ClipboardData?
    let version: Int
    let message: String?
}

struct ClipboardData: Codable {
    let contentType: String
    let content: String
    let metadata: String
    let createdAt: String
    let version: Int
    
    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case content
        case metadata
        case createdAt = "created_at"
        case version
    }
}

// MARK: - Error Types
enum CopyPastaError: Error, LocalizedError {
    case notConfigured
    case authenticationFailed
    case httpError(Int)
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "CopyPasta client is not configured"
        case .authenticationFailed:
            return "Authentication failed"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .networkError:
            return "Network error"
        }
    }
}