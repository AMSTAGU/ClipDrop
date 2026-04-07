import SwiftUI
import Combine
import AppKit
import UserNotifications

// MARK: - Core Logic Services

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

class AirDropService {
    static let shared = AirDropService()
    func shareFileViaAirDrop(fileURL: URL) {
        let service = NSSharingService(named: .sendViaAirDrop)
        let items: [Any] = [fileURL]
        if let service = service, service.canPerform(withItems: items) {
            service.perform(withItems: items)
        }
    }
}

class DownloadMonitor: ObservableObject {
    static let shared = DownloadMonitor()
    private let fileManager = FileManager.default
    private var source: DispatchSourceFileSystemObject?
    
    @Published var lastReceivedText: String?
    @Published var isFolderAuthorized: Bool = false
    @Published var isNotificationAuthorized: Bool = false
    @Published var isMonitoringActive: Bool = false
    
    private var downloadsURL: URL {
        // Obtenir le chemin mémorisé via NSOpenPanel s'il a été autorisé manuellement
        if let customPath = UserDefaults.standard.string(forKey: "customDownloadsPath") {
            return URL(fileURLWithPath: customPath)
        }
        
        // S'échapper du bac à sable (Sandbox) pour trouver les vrais téléchargements
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
        // 1. Check Folder Access
        do {
            let _ = try fileManager.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: nil)
            isFolderAuthorized = true
        } catch {
            isFolderAuthorized = false
        }
        
        // 2. Check Notification Access
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
        // Close existing source if any
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
                        // Fallback if addedToDirectoryDate isn't available
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

class SharedNotificationManager {
    static func requestPermission(completion: @escaping (Bool) -> Void = { _ in }) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .denied {
                openSettings()
                DispatchQueue.main.async { completion(false) }
            } else {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            }
        }
    }
    
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications") {
            NSWorkspace.shared.open(url)
        }
    }
    
    static func post(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
    
    static func triggerAppleEventsPermission() {
        let script = "tell application \"Finder\" to get version"
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            appleScript.executeAndReturnError(&error)
        }
    }
}

// MARK: - App Entry Point

@main
struct Aidrop_ClipboardApp: App {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @StateObject private var monitor = DownloadMonitor.shared
    
    init() {
        // Soft check on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    var body: some Scene {
        MenuBarExtra("Airdrop Clipboard", systemImage: "paperplane.fill") {
            ContentView()
                .environmentObject(monitor)
        }
        .menuBarExtraStyle(.window)
    }
}
