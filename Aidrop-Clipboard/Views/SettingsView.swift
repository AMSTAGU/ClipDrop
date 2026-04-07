import SwiftUI
import ServiceManagement

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
                Text("Settings")
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
                        Text("GENERAL")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Launch at login")
                                        .font(.system(.subheadline, design: .rounded))
                                        .fontWeight(.medium)
                                    Text("Auto-start on boot")
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
                                            print("Failed to toggle login item \(error)")
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
                                    Text("Alerts when copying")
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
                        Text("PERMISSIONS")
                            .font(.system(.caption, design: .rounded))
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 0) {
                            PermissionRowPremium(
                                title: "Downloads",
                                subtitle: "Access to reception folder",
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
