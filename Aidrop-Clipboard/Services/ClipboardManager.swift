import Foundation
import AppKit

class ClipboardManager {
    static let shared = ClipboardManager()
    private let pasteboard = NSPasteboard.general

    // Magic header: 4 null bytes + "CLIPDROP" ASCII.
    // The leading 0x00 bytes force macOS content-sniffing to classify
    // the file as opaque binary (public.data), NOT public.plain-text.
    // TextEdit cannot open public.data files → it never launches.
    private static let magic = Data([0x00, 0x00, 0x00, 0x00,
                                     0x43, 0x4C, 0x49, 0x50,
                                     0x44, 0x52, 0x4F, 0x50]) // "CLIPDROP"

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
        let fileURL = tempDirectory.appendingPathComponent("clipboard.aidropclip")

        guard let textData = text.data(using: .utf8) else { return nil }

        // Format: [12-byte magic][4-byte big-endian length][UTF-8 text]
        var payload = Self.magic
        var length = UInt32(textData.count).bigEndian
        payload.append(contentsOf: withUnsafeBytes(of: &length) { Array($0) })
        payload.append(textData)

        try? payload.write(to: fileURL, options: .atomic)
        return fileURL
    }

    /// Decode a file produced by createSharedFile().
    /// Also handles legacy binary plist format for backward compat.
    static func extractText(from data: Data) -> String? {
        // New format: starts with 4 null bytes
        if data.count > 16, data[0] == 0x00, data[1] == 0x00,
           data[2] == 0x00, data[3] == 0x00 {
            let textData = data.dropFirst(16) // 12 magic + 4 length
            return String(data: textData, encoding: .utf8)
        }
        // Legacy binary plist format
        if let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
           let text = dict["t"] {
            return text
        }
        // Last resort: raw UTF-8
        return String(data: data, encoding: .utf8)
    }
}

