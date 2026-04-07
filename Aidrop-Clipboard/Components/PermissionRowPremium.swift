import SwiftUI

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
                            Text("Active")
                        }
                        .font(.system(.caption, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                    }
                    .frame(width: 65, height: 26)
                } else {
                    Button(action: action) {
                        Text("Grant")
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
