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
            Logger.log("ClipboardMonitor", "Detected image content")
            return (content: "data:image/png;base64,\(base64String)", type: .image)
        }
        
        // Get plain text for comparison
        let plainText = pasteboard.string(forType: .string) ?? ""
        
        // Check for rich text (RTF)
        if let rtfData = pasteboard.data(forType: .rtf) {
            if let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                // Check if this is terminal styling vs actual rich content
                if isTerminalStyling(attributedString: attributedString, plainText: plainText) {
                    Logger.log("ClipboardMonitor", "Detected terminal styling - treating as plain text")
                    return (content: plainText, type: .text)
                }
                
                // Convert to HTML for rich text
                if let htmlData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
                                                            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
                    let htmlString = String(data: htmlData, encoding: .utf8) ?? attributedString.string
                    Logger.log("ClipboardMonitor", "Detected rich text content")
                    return (content: htmlString, type: .richText)
                }
            }
        }
        
        // Check for plain text
        if !plainText.isEmpty {
            Logger.log("ClipboardMonitor", "Detected plain text content")
            return (content: plainText, type: .text)
        }
        
        return nil
    }
    
    private func isTerminalStyling(attributedString: NSAttributedString, plainText: String) -> Bool {
        // Check if RTF text matches plain text
        let rtfText = attributedString.string
        if rtfText != plainText {
            return false
        }
        
        let fullRange = NSRange(location: 0, length: attributedString.length)
        var attributeRanges: [(NSRange, [NSAttributedString.Key: Any])] = []
        var hasRichFormatting = false
        
        // Collect all attribute ranges and check for rich formatting
        attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, stop in
            attributeRanges.append((range, attributes))
            
            // Check for rich formatting attributes that indicate actual rich content
            for (key, value) in attributes {
                switch key {
                case .underlineStyle, .strikethroughStyle:
                    if let styleValue = value as? Int, styleValue != 0 {
                        hasRichFormatting = true
                        stop.pointee = true
                    }
                case .link, .attachment:
                    hasRichFormatting = true
                    stop.pointee = true
                default:
                    if key.rawValue.contains("Shadow") || key.rawValue.contains("Stroke") || key.rawValue.contains("Outline") {
                        hasRichFormatting = true
                        stop.pointee = true
                    }
                }
            }
        }
        
        if hasRichFormatting {
            return false
        }
        
        // Check if we have a single formatting block (terminal-like) or uniform formatting
        if attributeRanges.count == 1 {
            let (_, attributes) = attributeRanges[0]
            
            // Check if it uses a monospace font
            if let font = attributes[.font] as? NSFont {
                return font.isFixedPitch
            }
        } else {
            // Multiple ranges - check if they all use the same monospace font (like colored terminal output)
            var fonts: Set<String> = []
            var allMonospace = true
            
            for (_, attributes) in attributeRanges {
                if let font = attributes[.font] as? NSFont {
                    fonts.insert(font.fontName)
                    if !font.isFixedPitch {
                        allMonospace = false
                        break
                    }
                }
            }
            
            // If all ranges use the same monospace font, it's likely terminal output with colors
            return fonts.count == 1 && allMonospace
        }
        
        return false
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