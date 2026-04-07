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
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey]
        let files = try? fileManager.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: keys)
        let now = Date()
        
        files?.forEach { url in
            if url.pathExtension == "clipboard" {
                process(url)
            } else if url.pathExtension == "txt" {
                let filename = url.deletingPathExtension().lastPathComponent.lowercased()
                if filename.hasPrefix("text") || filename.hasPrefix("note") || filename.hasPrefix("extrait") {
                    if let attrs = try? url.resourceValues(forKeys: Set(keys)), let addedDate = attrs.addedToDirectoryDate {
                        if now.timeIntervalSince(addedDate) < 15 {
                            process(url)
                        }
                    } else {
                        let attrs2 = try? url.resourceValues(forKeys: [.creationDateKey])
                        if let creationDate = attrs2?.creationDate, now.timeIntervalSince(creationDate) < 15 {
                            process(url)
                        }
                    }
                }
            }
        }
    }
    
    private func process(_ url: URL) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                if !text.isEmpty {
                    ClipboardManager.shared.copyToClipboard(text: text)
                    self.lastReceivedText = text
                    if UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true {
                        SharedNotificationManager.post(title: "AirDrop Clipboard", message: "Text reçu et copié !")
                    }
                    try self.fileManager.removeItem(at: url)
                    self.closeAirDropWindows()
                }
            } catch {
                print("Processing error: \(error)")
            }
        }
    }
    
    private func closeAirDropWindows() {
        let appleScript = """
        try
            tell application "Finder"
                if (count of windows) > 0 then
                    if name of front window is "Downloads" or name of front window is "Téléchargements" then
                        close front window
                    end if
                end if
            end tell
        end try
        try
            tell application "TextEdit"
                if (count of documents) > 0 then
                    close front document saving no
                end if
            end tell
        end try
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)
        }
    }
}
