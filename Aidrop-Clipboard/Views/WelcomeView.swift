import SwiftUI

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
