import Foundation
import AppKit
import CoreServices

/// Registers this app as the default handler for .txt (public.plain-text)
/// and .clipboard files so that LaunchServices never opens TextEdit when
/// AirDrop delivers a text file.
///
/// How it works:
///   - AirDrop delivers a .txt → LaunchServices looks for the default handler
///     for "public.plain-text" → finds THIS app → launches it silently
///   - Our DownloadMonitor already watches Downloads and processes the file
///   - Because we're a LSUIElement app (no Dock icon, no window), we open
///     invisibly, copy the text to the clipboard, delete the file, done.
///
/// The launchd WatchPaths agent is kept as a belt-and-suspenders backup
/// to close any Finder window that may open.
class LaunchAgentInstaller {
    static let shared = LaunchAgentInstaller()

    private let agentLabel = "com.airdropclipboard.watcher"
    private let ourBundleID = "com.Amaury.Aidrop-Clipboard"

    private var launchAgentsDir: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/LaunchAgents")
    }

    private var plistURL: URL {
        launchAgentsDir.appendingPathComponent("\(agentLabel).plist")
    }

    private var scriptURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/AirdropClipboard/watcher.sh")
    }

    private var downloadsPath: String {
        if let customPath = UserDefaults.standard.string(forKey: "customDownloadsPath") {
            return customPath
        }
        let sandboxHome = NSHomeDirectory()
        if let range = sandboxHome.range(of: "/Library/Containers") {
            let realHome = String(sandboxHome[..<range.lowerBound])
            return realHome + "/Downloads"
        }
        return (FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first?.path)
            ?? (NSHomeDirectory() + "/Downloads")
    }

    // MARK: - Public API

    func installIfNeeded() {
        // 1. Register as default handler for .txt / .clipboard
        //    This is the primary fix — LaunchServices will open US instead of TextEdit.
        registerAsDefaultHandler()

        // 2. Keep the launchd agent as a fallback to close Finder windows
        do {
            try writeScript()
            try writePlist()
            loadAgent()
        } catch {
            print("[LaunchAgentInstaller] Failed to install launchd agent: \(error)")
        }
    }

    func uninstall() {
        // Restore TextEdit as the default for plain text on quit
        restoreTextEditAsDefault()
        unloadAgent()
        try? FileManager.default.removeItem(at: plistURL)
        try? FileManager.default.removeItem(at: scriptURL)
    }

    // MARK: - Handler registration

    private func registerAsDefaultHandler() {
        // Must be done on a background thread so it doesn't block launch
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self else { return }
            let utis: [CFString] = [
                "public.plain-text" as CFString,
                "public.text" as CFString,
                "com.apple.traditional-mac-plain-text" as CFString
            ]
            let bundleID = self.ourBundleID as CFString
            for uti in utis {
                let result = LSSetDefaultRoleHandlerForContentType(uti, .all, bundleID)
                if result == noErr {
                    print("[LaunchAgentInstaller] Registered as default for \(uti)")
                } else {
                    print("[LaunchAgentInstaller] Failed to register for \(uti): \(result)")
                }
            }
        }
    }

    private func restoreTextEditAsDefault() {
        let textEditID = "com.apple.TextEdit" as CFString
        LSSetDefaultRoleHandlerForContentType("public.plain-text" as CFString, .all, textEditID)
        LSSetDefaultRoleHandlerForContentType("public.text" as CFString, .all, textEditID)
    }

    // MARK: - launchd agent (fallback: closes Finder Downloads window)

    private func writeScript() throws {
        let dir = scriptURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let script = """
        #!/bin/bash
        # Fallback: close the Finder Downloads window if it appeared.
        osascript -e '
        try
            tell application "Finder"
                repeat with w in windows
                    if name of w is "Downloads" or name of w is "Téléchargements" then
                        close w
                    end if
                end repeat
            end tell
        end try' 2>/dev/null
        # Belt-and-suspenders: if TextEdit somehow launched, kill it
        pkill -x "TextEdit" 2>/dev/null
        """
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        var attrs = (try? FileManager.default.attributesOfItem(atPath: scriptURL.path)) ?? [:]
        attrs[.posixPermissions] = 0o755
        try FileManager.default.setAttributes(attrs, ofItemAtPath: scriptURL.path)
    }

    private func writePlist() throws {
        try FileManager.default.createDirectory(at: launchAgentsDir, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "Label": agentLabel,
            "ProgramArguments": ["/bin/bash", scriptURL.path],
            "WatchPaths": [downloadsPath],
            "RunAtLoad": false
        ]

        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        try data.write(to: plistURL, options: .atomic)
    }

    private func loadAgent() {
        // Use launchctl bootout/bootstrap for modern macOS if possible,
        // but load/unload is often more reliable for user-level LaunchAgents.
        unloadAgent()
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["load", "-w", plistURL.path]
        try? task.run()
        task.waitUntilExit()
    }

    private func unloadAgent() {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["unload", plistURL.path]
        try? task.run()
        task.waitUntilExit()
    }
}
