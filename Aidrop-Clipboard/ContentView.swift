import SwiftUI
import Combine
import ServiceManagement

struct ContentView: View {
    @EnvironmentObject var monitor: DownloadMonitor
    @State private var currentClipboard: String = ""
    @State private var showingSettings = false
    
    private let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
    
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding: Bool = false
    
    var body: some View {
        ZStack {
            if showingSettings {
                SettingsView(showingSettings: $showingSettings, monitor: monitor)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            } else {
                mainContent
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
            }
            
            if !hasSeenOnboarding {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()
                WelcomeView(hasSeenOnboarding: $hasSeenOnboarding, monitor: monitor)
            }
        }
        .frame(width: 320)
        .animation(.spring(), value: showingSettings)
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
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "paperplane.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue.gradient)
                VStack(alignment: .leading) {
                    Text("Airdrop Clipboard")
                        .font(.headline)
                    Text("Auto-copies incoming text")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                // Settings Button
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.trailing, 8)
                
                // Power Button
                Button(action: { NSApplication.shared.terminate(nil) }) {
                    Image(systemName: "power")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary) // Changed from red
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Clipboard Preview Card
            VStack(alignment: .leading, spacing: 8) {
                Text("CURRENT CLIPBOARD")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .shadow(radius: 2, y: 1)
                    
                    ScrollView {
                        Text(currentClipboard.isEmpty ? "Clipboard is empty" : currentClipboard)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(currentClipboard.isEmpty ? .secondary : .primary)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                }
                .frame(height: 120)
            }
            .padding(.horizontal)
            
            // Share Button
            Button(action: shareClipboard) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("AirDrop to another Mac")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(currentClipboard.isEmpty ? Color.gray.gradient : Color.blue.gradient)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(currentClipboard.isEmpty)
            .padding(.horizontal)
            
            // Notification Area / Last Received
            if let last = monitor.lastReceivedText {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Received & Copied")
                        .font(.caption2)
                        .fontWeight(.bold)
                    Spacer()
                    Text(last.prefix(15) + "...")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 12) // Reduced from 20
            } else {
                Spacer().frame(height: 12) // Reduced from 20
            }
        }
    }
    
    private func refreshClipboard() {
        currentClipboard = ClipboardManager.shared.getClipboardContent() ?? ""
    }
    
    private func shareClipboard() {
        guard let fileURL = ClipboardManager.shared.createSharedFile() else { return }
        AirDropService.shared.shareFileViaAirDrop(fileURL: fileURL)
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Binding var showingSettings: Bool
    @ObservedObject var monitor: DownloadMonitor
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { showingSettings = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                Text("Paramètres")
                    .font(.headline)
                Spacer()
                
                // Add a hidden button for balance
                Image(systemName: "chevron.left").opacity(0)
            }
            .padding()
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.8))
            
            ScrollView {
                VStack(spacing: 20) {
                    
                    // GENERAL
                    VStack(alignment: .leading, spacing: 8) {
                        Text("GÉNÉRAL")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            Toggle("Lancer au démarrage", isOn: $launchAtLogin)
                                .toggleStyle(.switch)
                                .padding()
                                .onChange(of: launchAtLogin) { newValue in
                                    do {
                                        if newValue {
                                            try SMAppService.mainApp.register()
                                        } else {
                                            try SMAppService.mainApp.unregister()
                                        }
                                    } catch {
                                        print("Failed to toggle login item \(error)")
                                        launchAtLogin = !newValue
                                    }
                                }
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                    }
                    
                    // PERMISSIONS
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AUTORISATIONS")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            PermissionRowPremium(
                                title: "Notifications",
                                subtitle: "Alertes lors d'une copie",
                                isAuthorized: monitor.isNotificationAuthorized,
                                icon: "bell.fill",
                                iconColor: .blue,
                                showDivider: true,
                                action: { 
                                    SharedNotificationManager.requestPermission { _ in
                                        monitor.checkPermissions()
                                    }
                                }
                            )
                            
                            PermissionRowPremium(
                                title: "Téléchargements",
                                subtitle: "Accès au dossier de réception",
                                isAuthorized: monitor.isFolderAuthorized,
                                icon: "folder.fill",
                                iconColor: .indigo,
                                showDivider: false,
                                action: {
                                    monitor.requestFolderAccess()
                                }
                            )
                        }
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .controlBackgroundColor)))
                    }
                    
                }
                .padding()
            }
            
            Text("Airdrop Clipboard v1.0")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 12)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct PermissionRowPremium: View {
    let title: String
    let subtitle: String
    let isAuthorized: Bool
    let icon: String
    let iconColor: Color
    let showDivider: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .foregroundStyle(iconColor)
                        .font(.system(size: 14, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isAuthorized {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Autorisé")
                    }
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Capsule())
                } else {
                    Button(action: action) {
                        Text("Accorder")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            
            if showDivider {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }
}

// MARK: - Onboarding View

struct WelcomeView: View {
    @Binding var hasSeenOnboarding: Bool
    @ObservedObject var monitor: DownloadMonitor
    
    var body: some View {
        VStack(spacing: 25) {
            Image(systemName: "paperplane.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.blue.gradient)
            
            VStack(spacing: 12) {
                Text("Bienvenue sur Airdrop Clipboard")
                    .font(.title3)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Pour fonctionner, l'app demande les accès suivants :")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 15) {
                FeatureRow(icon: "bell.badge.fill", title: "Notifications", desc: "Pour vous alerter quand le texte est copié.")
                FeatureRow(icon: "folder.fill", title: "Dossier Téléchargements", desc: "Pour auto-copier et nettoyer les fichiers AirDrop.")
                FeatureRow(icon: "macwindow", title: "Masquer les fenêtres", desc: "Pour rendre le système transparent en refermant la fenêtre AirDrop.")
            }
            .padding(.vertical)
            
            Button(action: authorizeAll) {
                Text("Autoriser et démarrer")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(30)
    }
    
    private func authorizeAll() {
        // Sequentially ask
        SharedNotificationManager.requestPermission { _ in
            monitor.requestFolderAccess()
            // Trigger AppleEvents prompt
            SharedNotificationManager.triggerAppleEventsPermission()
            
            withAnimation {
                hasSeenOnboarding = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
