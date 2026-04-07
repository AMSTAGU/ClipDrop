import SwiftUI
import UserNotifications

@main
struct Aidrop_ClipboardApp: App {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    @StateObject private var monitor = DownloadMonitor.shared
    
    init() {
        // Install system-level launchd watcher to kill TextEdit before it appears
        LaunchAgentInstaller.shared.installIfNeeded()
        // Soft check on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    var body: some Scene {
        MenuBarExtra("Airdrop Clipboard", systemImage: "paperplane.fill") {
            ContentView()
                .environmentObject(monitor)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    LaunchAgentInstaller.shared.uninstall()
                }
        }
        .menuBarExtraStyle(.window)
    }
}
