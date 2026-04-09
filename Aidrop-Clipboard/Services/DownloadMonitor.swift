import Foundation
import Combine
import AppKit
import UserNotifications

class DownloadMonitor: ObservableObject {
    static let shared = DownloadMonitor()
    private let fileManager = FileManager.default
    private var source: DispatchSourceFileSystemObject?
    private var pollingTimer: Timer?

    @Published var lastReceivedText: String?
    @Published var isFolderAuthorized: Bool = false
    @Published var isNotificationAuthorized: Bool = false
    @Published var isMonitoringActive: Bool = false

    // Set to true for 10s after we detect an incoming AirDrop file.
    // The NSWorkspace observer only kills TextEdit during this window.
    private var airDropWindowActive = false
    private var airDropWindowTask: DispatchWorkItem?

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
        installTextEditGuard()
    }

    // MARK: - TextEdit guard (NSWorkspace observer)

    /// Layer 1: Watch for TextEdit launching. If it launches within our
    /// AirDrop detection window (10s), kill it before it shows a window.
    private func installTextEditGuard() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  self.airDropWindowActive,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.TextEdit"
            else { return }

            // TextEdit launched right after we saw an AirDrop file → kill it.
            app.forceTerminate()
            print("[DownloadMonitor] Intercepted and killed TextEdit (AirDrop guard)")
        }

        // Also watch for TextEdit that was already running before us
        // and has just been brought to front with a new file.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  self.airDropWindowActive,
                  let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.TextEdit"
            else { return }

            app.forceTerminate()
            print("[DownloadMonitor] Killed already-running TextEdit (AirDrop guard)")
        }
    }

    private func activateAirDropWindow() {
        airDropWindowActive = true
        airDropWindowTask?.cancel()
        let task = DispatchWorkItem { [weak self] in self?.airDropWindowActive = false }
        airDropWindowTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 10, execute: task)
    }

    // MARK: - Permissions

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
        panel.message = "Please select your Downloads folder to authorize the app."
        panel.prompt = "Authorize Access"
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

    // MARK: - Monitoring

    func startMonitoring() {
        source?.cancel()
        pollingTimer?.invalidate()

        let descriptor = open(downloadsURL.path, O_EVTONLY)
        guard descriptor >= 0 else {
            isMonitoringActive = false
            return
        }

        isMonitoringActive = true

        // Layer 2a: Directory change event (fires within ~50ms of file arrival)
        source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source?.setEventHandler { [weak self] in self?.checkForNewFiles() }
        source?.setCancelHandler { close(descriptor) }
        source?.resume()

        // Layer 2b: 500ms polling timer as belt-and-suspenders.
        // Some AirDrop deliveries land without triggering the directory event.
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForNewFiles()
        }

        checkForNewFiles()
    }

    func checkForNewFiles() {
        let keys: [URLResourceKey] = [.addedToDirectoryDateKey, .creationDateKey]
        let files = try? fileManager.contentsOfDirectory(at: downloadsURL, includingPropertiesForKeys: keys)
        let now = Date()

        files?.forEach { url in
            let ext = url.pathExtension.lowercased()
            guard ext == "aidropclip" || ext == "clipboard" else { return }

            let attrs = try? url.resourceValues(forKeys: Set(keys))
            let date = attrs?.addedToDirectoryDate ?? attrs?.creationDate
            guard let date, now.timeIntervalSince(date) < 30 else { return }

            DispatchQueue.main.async { self.activateAirDropWindow() }
            closeAirDropWindows()
            process(url)
        }
    }

    // MARK: - Cleanup helpers

    /// Close any Finder Downloads windows that macOS opens after AirDrop delivery.
    /// Uses osascript so it's safe to call from any thread.
    private func closeAirDropWindows() {
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", """
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
    }

    // MARK: - File processing

    private var processedURLs = Set<URL>()

    func processFromDelegate(_ url: URL) {
        // Called by AppDelegate.application(_:open:) — same logic, public entry point.
        activateAirDropWindow()
        closeAirDropWindows()
        process(url)
    }

    private func process(_ url: URL, attempt: Int = 0) {
        guard !processedURLs.contains(url) else { return }
        processedURLs.insert(url)

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            do {
                let data = try Data(contentsOf: url)
                guard let text = ClipboardManager.extractText(from: data), !text.isEmpty else {
                    if attempt < 5 {
                        processedURLs.remove(url)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            self.process(url, attempt: attempt + 1)
                        }
                    } else {
                        processedURLs.remove(url)
                    }
                    return
                }

                // Delete file FIRST — before macOS can route it to TextEdit.
                try? self.fileManager.removeItem(at: url)
                processedURLs.remove(url)

                DispatchQueue.main.async {
                    ClipboardManager.shared.copyToClipboard(text: text)
                    self.lastReceivedText = text
                    if UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true {
                        SharedNotificationManager.post(title: "AirDrop Clipboard", message: "Text received and copied!")
                    }
                }
            } catch {
                if attempt < 5 {
                    processedURLs.remove(url)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.process(url, attempt: attempt + 1)
                    }
                } else {
                    print("[DownloadMonitor] Processing error: \(error)")
                    processedURLs.remove(url)
                }
            }
        }
    }
}
