import SwiftUI

struct ArrowBtn: View {
    let sys: String; let w: CGFloat; let h: CGFloat; let fn: () -> Void
    @Environment(\.colorScheme) private var cs
    @State private var pressed = false
    @StateObject private var rt = RT()

    private var bgCol: Color { cs == .dark ? Color(white: 0.14) : Color(white: 0.93) }
    private var borderCol: Color { cs == .dark ? .white.opacity(0.06) : .black.opacity(0.06) }
    private var shadowCol: Color { .black.opacity(cs == .dark ? 0.50 : 0.13) }
    private var fgCol: Color { cs == .dark ? Color(white: 0.94) : Color(white: 0.10) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5.0, style: .continuous)
                .fill(bgCol)
                .overlay(RoundedRectangle(cornerRadius: 5.0, style: .continuous)
                    .strokeBorder(borderCol, lineWidth: 0.5))
                .shadow(color: shadowCol, radius: 2.0, x: 0.0, y: 1.5)
            Image(systemName: sys)
                .font(.system(size: max(7.0, h * 0.30), weight: .semibold))
                .foregroundStyle(fgCol)
        }
        .frame(width: w, height: h)
        .scaleEffect(pressed ? 0.93 : 1.0).brightness(pressed ? -0.08 : 0.0)
        .animation(.easeOut(duration: 0.08), value: pressed)
        .gesture(DragGesture(minimumDistance: 0.0)
            .onChanged { _ in guard !pressed else { return }; pressed = true; rt.t.start { fn() } }
            .onEnded   { _ in pressed = false; rt.t.cancel() })
    }
}
