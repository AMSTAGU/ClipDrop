import SwiftUI

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
