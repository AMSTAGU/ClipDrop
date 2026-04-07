import SwiftUI
import Combine

struct ContentView: View {
    @EnvironmentObject var monitor: DownloadMonitor
    @State private var currentClipboard: String = ""
    @State private var showingSettings = false
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    
    var body: some View {
        ZStack {
            AmbientBackground()
            
            if showingSettings {
                SettingsView(showingSettings: $showingSettings, monitor: monitor)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .trailing).combined(with: .opacity)))
            } else {
                mainContent
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
            
            if !hasSeenOnboarding {
                Color.black.opacity(0.3).ignoresSafeArea() // Backdrop
                WelcomeView(hasSeenOnboarding: $hasSeenOnboarding, monitor: monitor)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .zIndex(10)
            }
        }
        .frame(width: 340) // Slightly wider for elegance
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: showingSettings)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasSeenOnboarding)
        .onAppear {
            refreshClipboard()
            monitor.startMonitoring()
        }
        .onReceive(timer) { _ in
            refreshClipboard()
            monitor.checkForNewFiles()
        }
    }
    
    private var mainContent: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .offset(x: -1, y: 1) // optical adjustment for paperplane
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Airdrop Clipboard")
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.bold)
                    Text("Ready to receive")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                // Top Right Controls in a mini glass pill
                HStack(spacing: 12) {
                    Button(action: { showingSettings = true }) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    
                    Button(action: { NSApplication.shared.terminate(nil) }) {
                        Image(systemName: "power")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .liquidGlass(cornerRadius: 20)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Clipboard Preview Card
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.caption2)
                    Text("CURRENT CLIPBOARD")
                        .font(.system(.caption2, design: .rounded))
                        .fontWeight(.bold)
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                
                ZStack(alignment: .topLeading) {
                    ScrollView {
                        Text(currentClipboard.isEmpty ? "Waiting for copied text..." : currentClipboard)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(currentClipboard.isEmpty ? .tertiary : .primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .animation(.default, value: currentClipboard)
                    }
                }
                .frame(height: 140)
                .liquidGlass(cornerRadius: 16)
                .padding(.horizontal, 20)
            }
            
            // Share Button
            Button(action: shareClipboard) {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .bold))
                    Text("AirDrop to another Mac")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(currentClipboard.isEmpty ? Color.gray.gradient : Color.blue.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(currentClipboard.isEmpty)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }
    
    private func refreshClipboard() {
        let newContent = ClipboardManager.shared.getClipboardContent() ?? ""
        if currentClipboard != newContent {
            withAnimation(.spring()) {
                currentClipboard = newContent
            }
        }
    }
    
    private func shareClipboard() {
        guard let fileURL = ClipboardManager.shared.createSharedFile() else { return }
        AirDropService.shared.shareFileViaAirDrop(fileURL: fileURL)
    }
}
