import SwiftUI

struct InstructionOverlay: View {
    let onClose: () -> Void
    @Environment(\.colorScheme) private var cs
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    var body: some View {
        ZStack {
            (cs == .dark
                ? Color(red: 0.06, green: 0.06, blue: 0.09)
                : Color(red: 0.97, green: 0.97, blue: 0.99))
            .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    closeRow
                    VStack(spacing: isIPad ? 30 : 24) {
                        hero; gestures; banner; tips; startBtn
                    }
                    .padding(.horizontal, isIPad ? 40 : 20).padding(.bottom, 52)
                    .frame(maxWidth: isIPad ? 600 : .infinity)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    private var closeRow: some View {
        HStack {
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold)).foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.secondary.opacity(0.12)))
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, isIPad ? 40 : 20).padding(.top, 20).padding(.bottom, 6)
    }
    private var hero: some View {
        VStack(spacing: 8) {
            Text("How to Use")
                .font(.system(size: isIPad ? 13 : 11, weight: .semibold))
                .foregroundStyle(.blue).kerning(1.2).textCase(.uppercase)
            Text("Trackpad Guide")
                .font(.system(size: isIPad ? 36 : 30, weight: .bold, design: .rounded))
            Text("Your screen works like a MacBook trackpad.")
                .font(.system(size: isIPad ? 15 : 14)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }.padding(.top, 8).padding(.bottom, 4)
    }
    private var banner: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(cs == .dark ? 0.22 : 0.12))
                    .frame(width: isIPad ? 52 : 44, height: isIPad ? 52 : 44)
                Image(systemName: "iphone.gen3.landscape")
                    .font(.system(size: isIPad ? 22 : 18, weight: .semibold)).foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Use in Landscape Mode")
                    .font(.system(size: isIPad ? 15 : 14, weight: .semibold))
                Text("Rotate your phone sideways for the most trackpad area.")
                    .font(.system(size: isIPad ? 13 : 12)).foregroundStyle(.secondary)
                    .lineSpacing(2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(isIPad ? 16 : 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.orange.opacity(cs == .dark ? 0.07 : 0.05))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.orange.opacity(cs == .dark ? 0.28 : 0.22), lineWidth: 1)))
    }
    private var gestures: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gestures")
                .font(.system(size: isIPad ? 19 : 16, weight: .semibold, design: .rounded))
            VStack(spacing: 8) {
                GCard(icon: "cursorarrow.rays",     color: .blue,   title: "Move Cursor",
                      badge: "1 Finger",     desc: "Drag to move. Tap to click. Double tap to double click.")
                GCard(icon: "hand.tap",             color: .purple, title: "Right Click",
                      badge: "2 Finger Tap", desc: "Two-finger tap opens the context menu.")
                GCard(icon: "arrow.up.and.down.and.arrow.left.and.right",
                      color: .teal,   title: "Scroll",
                      badge: "2 Fingers",    desc: "Two fingers scroll in any direction.")
                GCard(icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                      color: .pink,   title: "Pinch & Zoom",
                      badge: "2 Fingers",    desc: "Pinch two fingers to zoom in or out.")
                GCard(icon: "text.cursor",           color: .green,  title: "Select Text",
                      badge: "3 Fingers",    desc: "Slowly drag with three fingers to select text.")
                GCard(icon: "square.3.layers.3d",   color: .indigo, title: "Mission Control",
                      badge: "4 Fingers",  desc: "Swipe up/down/left/right for spaces and Exposé.")
            }
        }
    }
    private var tips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tips").font(.system(size: isIPad ? 19 : 16, weight: .semibold, design: .rounded))
            VStack(spacing: 8) {
                TipRow(icon: "hand.draw",                  color: .purple, text: "Hold one finger for 0.4s to start drag mode.")
                TipRow(icon: "waveform.path.ecg",         color: .green,  text: "Haptic feedback confirms every tap.")
                TipRow(icon: "smallcircle.filled.circle", color: .blue,   text: "Tap the corner dot to reveal the back button.")
                TipRow(icon: "lock.rotation",             color: .orange, text: "Landscape mode gives the most trackpad surface.")
            }
        }
    }
    private var startBtn: some View {
        Button(action: onClose) {
            HStack(spacing: 8) {
                Text("Get Started").font(.system(size: isIPad ? 17 : 16, weight: .semibold))
                Image(systemName: "arrow.right").font(.system(size: isIPad ? 14 : 13, weight: .semibold))
            }
            .foregroundStyle(.white).frame(maxWidth: .infinity).frame(height: isIPad ? 56 : 52)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LinearGradient(colors: [.blue, .blue.opacity(0.82)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .blue.opacity(0.30), radius: 14, x: 0, y: 6))
        }
        .buttonStyle(.plain).padding(.top, 6)
    }
}
