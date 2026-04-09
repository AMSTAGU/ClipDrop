import AppKit
import Foundation

/// Handles files routed to us by Launch Services (e.g. when macOS AirDrop
/// delivers a .aidropclip and finds this app as the registered Owner).
/// This is the first line of defence — before DownloadMonitor's folder watch fires.
class AppDelegate: NSObject, NSApplicationDelegate {

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            guard ext == "aidropclip" || ext == "clipboard" else { continue }
            // Delegate to DownloadMonitor which owns the guard + clipboard logic.
            DownloadMonitor.shared.processFromDelegate(url)
        }
    }
}
