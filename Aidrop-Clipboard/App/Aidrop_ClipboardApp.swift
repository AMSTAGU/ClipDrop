import SwiftUI
import UserNotifications

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
