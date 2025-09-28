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
        // Debug: Print all available types on pasteboard
        let availableTypes = pasteboard.types ?? []
        print("=== CLIPBOARD DEBUG ===")
        print("Available pasteboard types: \(availableTypes)")
        
        // Check for images first
        if let imageData = pasteboard.data(forType: .tiff),
           let image = NSImage(data: imageData),
           let pngData = image.pngData {
            let base64String = pngData.base64EncodedString()
            print("DETECTED: Image content")
            return (content: "data:image/png;base64,\(base64String)", type: .image)
        }
        
        // Get plain text for comparison
        let plainText = pasteboard.string(forType: .string) ?? ""
        print("Plain text content: '\(plainText)'")
        print("Plain text length: \(plainText.count)")
        
        // Check for rich text (RTF)
        if let rtfData = pasteboard.data(forType: .rtf) {
            print("RTF data found, size: \(rtfData.count) bytes")
            
            if let attributedString = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
                print("RTF parsed successfully")
                print("RTF plain text: '\(attributedString.string)'")
                print("RTF plain text length: \(attributedString.string.count)")
                
                // Debug: Print all attributes in the RTF
                let fullRange = NSRange(location: 0, length: attributedString.length)
                print("RTF Attributes:")
                attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, stop in
                    print("  Range \(range): \(attributes)")
                }
                
                // Check if this is terminal styling vs actual rich content
                if isTerminalStyling(attributedString: attributedString, plainText: plainText) {
                    print("DETECTED: Terminal styling - treating as plain text")
                    return (content: plainText, type: .text)
                }
                
                // Convert to HTML for rich text
                if let htmlData = try? attributedString.data(from: NSRange(location: 0, length: attributedString.length),
                                                            documentAttributes: [.documentType: NSAttributedString.DocumentType.html]) {
                    let htmlString = String(data: htmlData, encoding: .utf8) ?? attributedString.string
                    print("HTML conversion successful")
                    print("HTML content: '\(htmlString)'")
                    print("HTML length: \(htmlString.count)")
                    print("DETECTED: Rich text content")
                    return (content: htmlString, type: .richText)
                } else {
                    print("HTML conversion failed")
                }
            } else {
                print("RTF parsing failed")
            }
        } else {
            print("No RTF data found")
        }
        
        // Check for plain text
        if !plainText.isEmpty {
            print("DETECTED: Plain text content")
            return (content: plainText, type: .text)
        }
        
        print("No supported content found")
        return nil
    }
    
    private func isTerminalStyling(attributedString: NSAttributedString, plainText: String) -> Bool {
        // Check if RTF text matches plain text
        let rtfText = attributedString.string
        if rtfText != plainText {
            print("Terminal check: RTF text differs from plain text")
            return false
        }
        
        let fullRange = NSRange(location: 0, length: attributedString.length)
        var attributeRanges: [(NSRange, [NSAttributedString.Key: Any])] = []
        var hasRichFormatting = false
        
        // Collect all attribute ranges
        attributedString.enumerateAttributes(in: fullRange, options: []) { attributes, range, stop in
            attributeRanges.append((range, attributes))
            
            // Check for rich formatting attributes that indicate actual rich content
            for (key, value) in attributes {
                switch key {
                case .underlineStyle, .strikethroughStyle:
                    if let styleValue = value as? Int, styleValue != 0 {
                        print("Terminal check: Text decoration detected - rich content")
                        hasRichFormatting = true
                        stop.pointee = true
                    }
                case .link, .attachment:
                    print("Terminal check: Links/attachments detected - rich content")
                    hasRichFormatting = true
                    stop.pointee = true
                default:
                    if key.rawValue.contains("Shadow") || key.rawValue.contains("Stroke") || key.rawValue.contains("Outline") {
                        print("Terminal check: Advanced text effects detected - rich content")
                        hasRichFormatting = true
                        stop.pointee = true
                    }
                }
            }
        }
        
        if hasRichFormatting {
            return false
        }
        
        print("Terminal check: Found \(attributeRanges.count) attribute ranges")
        
        // Check if we have a single formatting block (terminal-like) or uniform formatting
        if attributeRanges.count == 1 {
            let (range, attributes) = attributeRanges[0]
            print("Terminal check: Single attribute range covering \(range)")
            
            // Check if it uses a monospace font
            if let font = attributes[.font] as? NSFont {
                let isMonospace = font.isFixedPitch
                print("Terminal check: Font '\(font.fontName)' isMonospace=\(isMonospace)")
                
                if isMonospace {
                    print("Terminal check: Single monospace block detected - treating as terminal")
                    return true
                }
            }
        } else {
            // Multiple ranges - check if they all use the same monospace font (like colored terminal output)
            var fonts: Set<String> = []
            var allMonospace = true
            
            for (range, attributes) in attributeRanges {
                if let font = attributes[.font] as? NSFont {
                    fonts.insert(font.fontName)
                    if !font.isFixedPitch {
                        allMonospace = false
                        break
                    }
                }
            }
            
            print("Terminal check: \(attributeRanges.count) ranges with fonts: \(fonts), allMonospace=\(allMonospace)")
            
            // If all ranges use the same monospace font, it's likely terminal output with colors
            if fonts.count == 1 && allMonospace {
                print("Terminal check: Multiple ranges with same monospace font - treating as terminal")
                return true
            }
        }
        
        print("Terminal check: Not terminal styling - treating as rich content")
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