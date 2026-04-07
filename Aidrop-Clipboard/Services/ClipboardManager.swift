import Foundation
import AppKit

class ClipboardManager {
    static let shared = ClipboardManager()
    private let pasteboard = NSPasteboard.general
    
    func getClipboardContent() -> String? {
        return pasteboard.string(forType: .string)
    }
    
    func copyToClipboard(text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    
    func createSharedFile() -> URL? {
        let text = getClipboardContent() ?? ""
        let tempDirectory = FileManager.default.temporaryDirectory
        // Use .aidropclip extension AND binary plist format.
        // Binary plist starts with "bplist00" — macOS content-sniffing
        // identifies it as a plist, NOT plain text, so TextEdit never opens it.
        let fileURL = tempDirectory.appendingPathComponent("clipboard.aidropclip")
        let payload: [String: String] = ["t": text]
        if let data = try? PropertyListSerialization.data(fromPropertyList: payload, format: .binary, options: 0) {
            try? data.write(to: fileURL)
        }
        return fileURL
    }
}
