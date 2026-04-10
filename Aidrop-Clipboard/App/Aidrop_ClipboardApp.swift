import SwiftUI
import UserNotifications

@main
struct ClipDropApp: App {
    // Wire our AppDelegate so macOS calls application(_:open:)
    // when it delivers a .aidropclip file via AirDrop.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var monitor = DownloadMonitor.shared
    
    init() {
        // Soft check on launch
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    var body: some Scene {
        MenuBarExtra("ClipDrop", systemImage: "paperplane.fill") {
            ContentView()
                .environmentObject(monitor)
        }
        .menuBarExtraStyle(.window)
    }
}
