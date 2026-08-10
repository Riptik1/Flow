import SwiftUI

struct TrackpadCornerHintDot: View {
    let isIPad: Bool
    @Environment(\.colorScheme) private var cs
    var body: some View {
        Circle()
            .fill(cs == .dark ? Color.white.opacity(0.30) : Color.black.opacity(0.22))
            .frame(width: 36, height: 36)
            .offset(x: isIPad ? -6 : 1, y: isIPad ? -32 : -22)
    }
}

struct TrackpadBackButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var cs
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: "chevron.left").font(.system(size: isIPad ? 16 : 14, weight: .semibold))
                Text("Back").font(.system(size: isIPad ? 17 : 15, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, isIPad ? 20 : 16)
            .frame(height: isIPad ? 52 : 44)
            .background(
                Capsule().fill(Material.ultraThinMaterial)
                    .overlay(Capsule().stroke(cs == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.10), lineWidth: 0.8))
                    .shadow(color: .black.opacity(cs == .dark ? 0.45 : 0.15), radius: 12, x: 0, y: 3))
        }
        .buttonStyle(.plain)
    }
}
