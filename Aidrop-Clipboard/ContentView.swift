import SwiftUI
import Combine
import ServiceManagement

struct LiquidGlassModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white.opacity(0.4))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(colorScheme == .dark ? 0.3 : 0.8),
                                        .clear,
                                        .white.opacity(colorScheme == .dark ? 0.1 : 0.4)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat = 16) -> some View {
        modifier(LiquidGlassModifier(cornerRadius: cornerRadius))
    }
}

struct AmbientBackground: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base layer
            if colorScheme == .dark {
                Color(NSColor.windowBackgroundColor)
            } else {
                Color(NSColor.controlBackgroundColor).opacity(0.5)
            }
            
            // Ambient orbs
            Circle()
                .fill(Color.blue.opacity(colorScheme == .dark ? 0.2 : 0.15))
                .blur(radius: 60)
                .frame(width: 200, height: 200)
                .offset(x: animate ? -40 : 20, y: animate ? -50 : 30)
            
            Circle()
                .fill(Color.indigo.opacity(colorScheme == .dark ? 0.2 : 0.15))
                .blur(radius: 60)
                .frame(width: 250, height: 250)
                .offset(x: animate ? 20 : -40, y: animate ? 40 : -20)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

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

// MARK: - Settings View

struct SettingsView: View {
    @Binding var showingSettings: Bool
    @ObservedObject var monitor: DownloadMonitor
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { showingSettings = false }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .liquidGlass(cornerRadius: 16)
                
                Spacer()
                Text("Paramètres")
                    .font(.system(.headline, design: .rounded))
                    .fontWeight(.bold)
                Spacer()
                
                // Add a hidden button for balance
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
            
            ScrollView {
                VStack(spacing: 24) {
                    
                    // GENERAL
                    VStack(alignment: .leading, spacing: 10) {
                        Text("GÉNÉRAL")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Lancer au démarrage")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.medium)
                                    Text("Démarrage automatique")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $launchAtLogin)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .onChange(of: launchAtLogin) { newValue in
                                        do {
                                            if newValue {
                                                try SMAppService.mainApp.register()
                                            } else {
                                                try SMAppService.mainApp.unregister()
                                            }
                                        } catch {
                                            print("Failed to toggle login item \\(error)")
                                            launchAtLogin = !newValue
                                        }
                                    }
                            }
                            .padding(16)
                            
                            Divider().opacity(0.5).padding(.leading, 16)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notifications")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.medium)
                                    Text("Alertes lors d'une copie")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $notificationsEnabled)
                                    .toggleStyle(.switch)
                                    .labelsHidden()
                                    .onChange(of: notificationsEnabled) { newValue in
                                        if newValue {
                                            SharedNotificationManager.requestPermission { _ in
                                                monitor.checkPermissions()
                                            }
                                        }
                                    }
                            }
                            .padding(16)
                        }
                        .liquidGlass(cornerRadius: 16)
                    }
                    
                    // PERMISSIONS
                    VStack(alignment: .leading, spacing: 10) {
                        Text("AUTORISATIONS")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            PermissionRowPremium(
                                title: "Téléchargements",
                                subtitle: "Accès au dossier de réception",
                                isAuthorized: monitor.isFolderAuthorized,
                                icon: "arrow.down.doc.fill",
                                iconColors: [.blue, .cyan],
                                showDivider: false,
                                action: {
                                    monitor.requestFolderAccess()
                                }
                            )
                        }
                        .liquidGlass(cornerRadius: 16)
                    }
                    
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                
                Text("Airdrop Clipboard v1.0")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
            }
        }
    }
}

struct PermissionRowPremium: View {
    let title: String
    let subtitle: String
    let isAuthorized: Bool
    let icon: String
    let iconColors: [Color]
    let showDivider: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(LinearGradient(colors: iconColors, startPoint: .topLeading, endPoint: .bottomTrailing).opacity(0.15))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: icon)
                        .foregroundStyle(LinearGradient(colors: iconColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                        .font(.system(size: 16, weight: .semibold))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(.subheadline, design: .rounded))
                        .fontWeight(.semibold)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if isAuthorized {
                    ZStack {
                        Capsule().fill(Color.green.opacity(0.15))
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .black))
                            Text("Actif")
                        }
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    }
                    .frame(width: 65, height: 26)
                } else {
                    Button(action: action) {
                        Text("Accorder")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            
            if showDivider {
                Divider()
                    .padding(.leading, 68)
                    .opacity(0.5)
            }
        }
    }
}

// MARK: - Onboarding View

struct WelcomeView: View {
    @Binding var hasSeenOnboarding: Bool
    @ObservedObject var monitor: DownloadMonitor
    @State private var animateIcon = false
    
    var body: some View {
        ZStack {
            AmbientBackground()
            
            VStack(spacing: 30) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(animateIcon ? 1.1 : 0.9)
                        .animation(.easeInOut(duration: 2.0).repeatForever(), value: animateIcon)
                    
                    Image(systemName: "paperplane.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.top, 20)
                
                VStack(spacing: 12) {
                    Text("Liquid Glass Experience")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.black)
                        .multilineTextAlignment(.center)
                    
                    Text("Airdrop Clipboard nécessite quelques permissions pour vous offrir une expérience fluide et magique.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                }
                
                VStack(alignment: .leading, spacing: 0) {
                    FeatureRow(icon: "bell.and.waves.left.and.right", title: "Notifications", desc: "Pour vous alerter quand le texte est copié.", color: .pink)
                    Divider().padding(.leading, 60).opacity(0.5)
                    FeatureRow(icon: "folder.fill.badge.plus", title: "Dossier Transits", desc: "Auto-copie puissante des fichiers reçus.", color: .indigo)
                    Divider().padding(.leading, 60).opacity(0.5)
                    FeatureRow(icon: "eye.slash.fill", title: "Furtivité Intégrée", desc: "Referme la fenêtre pour un AirDrop invisible.", color: .gray)
                }
                .liquidGlass(cornerRadius: 20)
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button(action: authorizeAll) {
                    Text("Autoriser et démarrer")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            animateIcon = true
        }
    }
    
    private func authorizeAll() {
        SharedNotificationManager.requestPermission { _ in
            monitor.requestFolderAccess()
            SharedNotificationManager.triggerAppleEventsPermission()
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                hasSeenOnboarding = true
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let desc: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                Text(desc)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
    }
}

