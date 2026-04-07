import Foundation
import Combine
import AppKit
import UserNotifications

class DownloadMonitor: ObservableObject {
    static let shared = DownloadMonitor()
    private let fileManager = FileManager.default
    private var source: DispatchSourceFileSystemObject?
    
    @Published var lastReceivedText: String?
    @Published var isFolderAuthorized: Bool = false
    @Published var isNotificationAuthorized: Bool = false
    @Published var isMonitoringActive: Bool = false
    
    private var downloadsURL: URL {
        if let customPath = UserDefaults.standard.string(forKey: "customDownloadsPath") {
            return URL(fileURLWithPath: customPath)
        }
        
        let sandboxHome = NSHomeDirectory()
        if let range = sandboxHome.range(of: "/Library/Containers") {
            let realHome = String(sandboxHome[..<range.lowerBound])
            return URL(fileURLWithPath: realHome).appendingPathComponent("Downloads")
        }
        
        return fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    }
    
    init() { 
        startMonitoring() 
        checkPermissions()
    }
    
    func checkPermissions() {
        do {
            let _ = try fileManager.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: nil)
            isFolderAuthorized = true
        } catch {
            isFolderAuthorized = false
        }
        
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    func requestFolderAccess() {
        let panel = NSOpenPanel()
        panel.message = "Veuillez sélectionner votre dossier Téléchargements pour autoriser l'application."
        panel.prompt = "Autoriser l'accès"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = downloadsURL
        
        panel.begin { [weak self] response in
            if response == .OK, let selectedURL = panel.url {
                UserDefaults.standard.set(selectedURL.path, forKey: "customDownloadsPath")
                self?.checkPermissions()
                self?.startMonitoring()
            }
        }
    }
    
    func startMonitoring() {
        source?.cancel()
        
        let descriptor = open(downloadsURL.path, O_EVTONLY)
        guard descriptor >= 0 else { 
            isMonitoringActive = false
            return 
        }
        
        isMonitoringActive = true
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source?.setEventHandler { [weak self] in self?.checkForNewFiles() }
        source?.setCancelHandler { close(descriptor) }
        source?.resume()
        checkForNewFiles()
    }
    
    func checkForNewFiles() {
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .creationDateKey]
        let files = try? fileManager.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: keys)
        let now = Date()

        files?.forEach { url in
            let ext = url.pathExtension.lowercased()
            // .aidropclip = new custom extension (macOS doesn't know it → never opens an app)
            // .clipboard  = legacy support for older versions of the app
            if ext == "aidropclip" || ext == "clipboard" {
                // Only process files received in the last 30 seconds to avoid
                // re-processing old files on startup
                let attrs = try? url.resourceValues(forKeys: Set(keys))
                let date = attrs?.addedToDirectoryDate ?? attrs?.creationDate
                if let date, now.timeIntervalSince(date) < 30 {
                    process(url)
                }
            }
            // NOTE: .txt files are intentionally NOT handled here.
            // When a .txt lands in Downloads via AirDrop from an iPhone,
            // macOS will try to open it with TextEdit. That is the expected
            // macOS behaviour for a plain text file — our app doesn't intercept
            // arbitrary .txt files since it can't distinguish them from regular
            // downloads. The solution is to use .aidropclip on both sides.
        }
    }

    private var processedURLs = Set<URL>()

    private func process(_ url: URL, attempt: Int = 0) {
        // Avoid processing the same file twice
        guard !processedURLs.contains(url) else { return }
        processedURLs.insert(url)

        // Kill TextEdit immediately on the first detection, before even reading the file.
        // The launchd agent also handles this, but belt-and-suspenders.
        closeAirDropWindows()

        // Try to read and copy; retry up to 5 times with 200 ms gaps
        // in case the file is still being written by sharingd.
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            do {
                let data = try Data(contentsOf: url)
                // Try reading as binary plist first (new format),
                // fall back to plain UTF-8 text for legacy .clipboard files.
                let text: String
                if let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String],
                   let extracted = dict["t"] {
                    text = extracted
                } else {
                    text = String(data: data, encoding: .utf8) ?? ""
                }
                if !text.isEmpty {
                    try? self.fileManager.removeItem(at: url)
                    processedURLs.remove(url)
                    DispatchQueue.main.async {
                        ClipboardManager.shared.copyToClipboard(text: text)
                        self.lastReceivedText = text
                        if UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true {
                            SharedNotificationManager.post(title: "AirDrop Clipboard", message: "Text received and copied!")
                        }
                        // Second cleanup pass after a short delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            self.closeAirDropWindows()
                        }
                    }
                } else if attempt < 5 {
                    processedURLs.remove(url)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.process(url, attempt: attempt + 1)
                    }
                }
            } catch {
                if attempt < 5 {
                    processedURLs.remove(url)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.process(url, attempt: attempt + 1)
                    }
                } else {
                    print("Processing error: \(error)")
                    processedURLs.remove(url)
                }
            }
        }
    }
    
    private func closeAirDropWindows() {
        // IMPORTANT: NSAppleScript is NOT thread-safe — must execute on the main thread.
        // We dispatch_async so callers on background queues don't block.
        let runOnMain = {
            // Use Process/osascript so we're completely thread-safe and
            // don't need main-thread scheduling for NSAppleScript.
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", """
                try
                    tell application "TextEdit" to quit saving no
                end try
                try
                    tell application "Finder"
                        repeat with w in windows
                            if name of w is "Downloads" or name of w is "Téléchargements" then
                                close w
                            end if
                        end repeat
                    end tell
                end try
            """]
            try? task.run()
        }

        // osascript/Process is safe to call from any thread
        DispatchQueue.global(qos: .userInitiated).async {
            runOnMain()
        }
    }
}
