import Cocoa
import UniformTypeIdentifiers

enum ClipboardContentType {
    case text
    case richText
    case image
}

protocol ClipboardMonitorDelegate: AnyObject {
    func clipboardDidChange(content: String, type: ClipboardContentType)
}

class ClipboardMonitor {
    
    weak var delegate: ClipboardMonitorDelegate?
    
    private let pasteboard = NSPasteboard.general
    private var lastChangeCount = 0
    private var timer: Timer?
    private var isUpdatingFromServer = false
    
    init() {
        NSLog("ClipboardMonitor: init() started")
        NSLog("ClipboardMonitor: init() completed")
    }
    
    func startMonitoring() {
        Logger.log("ClipboardMonitor", "=== START MONITORING CALLED ===")
        print("ClipboardMonitor: startMonitoring() called")
        
        // Start monitoring with a slight delay to avoid blocking app launch
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            Logger.log("ClipboardMonitor", "=== DELAYED START EXECUTING ===")
            print("ClipboardMonitor: Delayed start executing")
            guard let self = self else { return }
            
            do {
                // Try to access pasteboard safely
                self.lastChangeCount = self.pasteboard.changeCount
                Logger.log("ClipboardMonitor", "Initial change count: \(self.lastChangeCount)")
                
                // Start timer on main thread
                self.timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                    self?.checkForChanges()
                }
                Logger.log("ClipboardMonitor", "Timer started successfully, polling every 0.5 seconds")
                
            } catch {
                Logger.logError("ClipboardMonitor", "Failed to access clipboard", error)
            }
        }
    }
    
    func stopMonitoring() {
        Logger.log("ClipboardMonitor", "Stopping clipboard monitoring")
        timer?.invalidate()
        timer = nil
    }
    
    private func checkForChanges() {
        let currentChangeCount = pasteboard.changeCount
        
        if currentChangeCount != lastChangeCount && !isUpdatingFromServer {
            Logger.log("ClipboardMonitor", "Clipboard change detected: \(lastChangeCount) -> \(currentChangeCount)")
            lastChangeCount = currentChangeCount
            handleClipboardChange()
        }
    }
    
    private func handleClipboardChange() {
        guard let content = getClipboardContent() else {
            Logger.log("ClipboardMonitor", "No supported content found in clipboard")
            return
        }
        
        Logger.log("ClipboardMonitor", "Clipboard changed: \(content.type), length: \(content.content.count)")
        delegate?.clipboardDidChange(content: content.content, type: content.type)
    }
    
    private func getClipboardContent() -> (content: String, type: ClipboardContentType)? {
        // Check for images first
        if let imageData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: imageData),
           let pngData = image.pngData {
            let base64String = pngData.base64EncodedString()
            return (content: "data:image/png;base64,\(base64String)", type: .image)
        }
        
        // Get plain text content for comparison
        let plainText = pasteboard.string(forType: .string) ?? ""
        
        // Check for rich text (RTF)
        if let rtfData = pasteboard.data(forType: .rtf),
           let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            
            // Check if RTF content is actually rich or just plain text with RTF wrapper
            if isActuallyRichContent(attributedString: attributedString, plainText: plainText) {
                // Convert to HTML for rich text
                if let htmlData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
                                                            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
                    let htmlString = String(data: htmlData, encoding: .utf8) ?? attributedString.string
                    return (content: htmlString, type: .richText)
                }
            } else {
                // RTF exists but content is equivalent to plain text, treat as plain text
                Logger.log("ClipboardMonitor", "RTF detected but content is plain text equivalent")
                return (content: plainText.isEmpty ? attributedString.string : plainText, type: .text)
            }
        }
        
        // Check for plain text
        if !plainText.isEmpty {
            return (content: plainText, type: .text)
        }
        
        return nil
    }
    
    private func isActuallyRichContent(attributedString: NSAttributedString, plainText: String) -> Bool {
        // If the attributed string's plain text is significantly different from clipboard plain text, it's rich
        let rtfPlainText = attributedString.string
        let normalizedRtfText = rtfPlainText.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedPlainText = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If texts don't match, it might be rich content
        if normalizedRtfText != normalizedPlainText {
            Logger.log("ClipboardMonitor", "Text mismatch detected - RTF: '\(normalizedRtfText.prefix(50))...', Plain: '\(normalizedPlainText.prefix(50))...'")
            return true
        }
        
        // Check for actual formatting attributes beyond the base font
        let fullRange = NSRange(location: 0, length: attributedString.length)
        var hasRichFormatting = false
        
        attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, stop in
            // Check for attributes that indicate rich formatting
            for (key, value) in attributes {
                switch key {
                case .font:
                    // Allow basic font but check for variations in font within the text
                    continue
                case .foregroundColor, .backgroundColor:
                    // Colors indicate rich formatting
                    hasRichFormatting = true
                    stop.pointee = true
                case .underlineStyle:
                    if let underlineValue = value as? Int, underlineValue != 0 {
                        hasRichFormatting = true
                        stop.pointee = true
                    }
                case .link, .attachment:
                    // Links and attachments are definitely rich content
                    hasRichFormatting = true
                    stop.pointee = true
                case .strikethroughStyle:
                    if let strikethroughValue = value as? Int, strikethroughValue != 0 {
                        hasRichFormatting = true
                        stop.pointee = true
                    }
                default:
                    // Other formatting attributes might indicate rich content
                    if key.rawValue.contains("Style") || key.rawValue.contains("Color") {
                        hasRichFormatting = true
                        stop.pointee = true
                    }
                }
            }
        }
        
        if hasRichFormatting {
            Logger.log("ClipboardMonitor", "Rich formatting attributes detected")
        } else {
            Logger.log("ClipboardMonitor", "No rich formatting detected - treating as plain text")
        }
        
        return hasRichFormatting
    }
    
    func setClipboardContent(content: String, type: ClipboardContentType) {
        Logger.log("ClipboardMonitor", "Setting clipboard content: \(type), length: \(content.count)")
        
        isUpdatingFromServer = true
        defer { isUpdatingFromServer = false }
        
        pasteboard.clearContents()
        
        switch type {
        case .text:
            pasteboard.setString(content, forType: .string)
            
        case .richText:
            // Try to parse HTML and convert to RTF
            if let htmlData = content.data(using: .utf8),
               let attributedString = try? NSAttributedString(
                data: htmlData,
                options: [.documentType: NSAttributedString.DocumentType.html],
                documentAttributes: nil
               ) {
                if let rtfData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
                                                           documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
                    pasteboard.setData(rtfData, forType: .rtf)
                } else {
                    // Fallback to plain text
                    pasteboard.setString(attributedString.string, forType: .string)
                }
            } else {
                // Fallback to plain text
                pasteboard.setString(content, forType: .string)
            }
            
        case .image:
            // Parse base64 image data
            if content.hasPrefix("data:image/") {
                let components = content.components(separatedBy: ",")
                if components.count == 2,
                   let imageData = Data(base64Encoded: components[1]),
                   let image = NSImage(data: imageData) {
                    pasteboard.setData(image.tiffRepresentation, forType: .tiff)
                }
            } else if let imageData = Data(base64Encoded: content),
                     let image = NSImage(data: imageData) {
                pasteboard.setData(image.tiffRepresentation, forType: .tiff)
            }
        }
        
        lastChangeCount = pasteboard.changeCount
    }
}

// Extension to convert NSImage to PNG data
extension NSImage {
    var pngData: Data? {
        guard let tiffData = tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else { return nil }
        return bitmapImage.representation(using: .png, properties: [:])
    }
}