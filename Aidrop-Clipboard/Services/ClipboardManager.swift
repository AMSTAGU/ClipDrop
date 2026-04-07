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
        let fileName = "copied_text.clipboard"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        try? text.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
