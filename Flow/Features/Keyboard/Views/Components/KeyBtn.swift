import SwiftUI

final class KeyPressState: ObservableObject {
    @Published var pressed = false
    var isDown = false
}

struct KeyBtn: View {
    let key: MKey; let width: CGFloat; let height: CGFloat
    let capsOn: Bool; let active: Bool; let fs: CGFloat
    let onPress: (MKey) -> Void
    @Environment(\.colorScheme) private var cs
    @StateObject private var ps = KeyPressState()
    @StateObject private var rt = RT()

    private var repeats: Bool {
        switch key.kind { case .modifier, .capsLock, .fn: return false; default: return true }
    }

    private var gradStart: Color { .white.opacity(cs == .dark ? 0.05 : 0.10) }
    private var gradEnd: Color { .white.opacity(0.0) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6.0, style: .continuous).fill(bg)
                .overlay(RoundedRectangle(cornerRadius: 6.0, style: .continuous).strokeBorder(border, lineWidth: 0.5))
                .overlay(LinearGradient(
                    colors: [gradStart, gradEnd],
                    startPoint: .top, endPoint: .center)
                    .clipShape(RoundedRectangle(cornerRadius: 6.0, style: .continuous)))
                .shadow(color: .black.opacity(cs == .dark ? 0.50 : 0.13), radius: 2.0, x: 0.0, y: 1.5)
            content
        }
        .frame(width: width, height: height)
        .overlay(alignment: .trailing) {
            if key.kind == .capsLock {
                let ledColor: Color = capsOn
                    ? Color(red: 0.18, green: 0.96, blue: 0.38)
                    : Color(white: cs == .dark ? 0.32 : 0.65).opacity(0.55)
                let ledShadow: Color = capsOn ? .green.opacity(0.95) : .clear
                Circle()
                    .fill(ledColor)
                    .frame(width: 5.0, height: 5.0)
                    .shadow(color: ledShadow, radius: 3.5)
                    .padding(.trailing, 7.0)
                    .allowsHitTesting(false)
            }
        }
        .scaleEffect(ps.pressed ? 0.93 : 1.0)
        .brightness(ps.pressed ? -0.08 : 0.0)
        .animation(.easeOut(duration: 0.08), value: ps.pressed)
        .gesture(DragGesture(minimumDistance: 0.0)
            .onChanged { _ in
                guard !ps.isDown else { return }
                ps.isDown = true
                ps.pressed = true
                if repeats { rt.t.start { onPress(key) } } else { onPress(key) }
            }
            .onEnded { _ in ps.isDown = false; ps.pressed = false; rt.t.cancel() })
    }

    @ViewBuilder private var content: some View {
        let lP = max(5.0, width  * 0.09)
        let bP = max(4.0, height * 0.11)
        let tP = max(4.0, height * 0.11)
        switch key.kind {
        case .space: Color.clear
        case .dual:
            VStack(spacing: 1.0) {
                Text(key.top).font(.system(size: max(7.0, fs * 0.56), weight: .medium))
                Text(key.label).font(.system(size: fs, weight: .medium))
            }.foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.4)
        case .letter:
            Text(capsOn ? key.label.uppercased() : key.label.lowercased())
                .font(.system(size: fs, weight: .regular)).foregroundStyle(fg)
                .lineLimit(1).minimumScaleFactor(0.4)
        case .fn:
            VStack(alignment: .leading, spacing: 0.0) {
                Image(systemName: "globe").font(.system(size: max(9.0, fs * 0.82), weight: .medium)).foregroundStyle(fg).padding(.top, tP)
                Spacer(minLength: 2.0)
                Text("fn").font(.system(size: max(7.0, fs * 0.64), weight: .medium)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.4).padding(.bottom, bP)
            }.padding(.leading, lP).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .modifier where key.label == "shift":
            VStack(alignment: .leading, spacing: 0.0) {
                Spacer(minLength: 0.0)
                Text("shift").font(.system(size: max(8.0, fs * 0.70), weight: .medium)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.35).padding(.bottom, bP)
            }.padding(.leading, lP).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .modifier:
            VStack(alignment: .leading, spacing: 0.0) {
                Text(sym).font(.system(size: max(10.0, fs * 0.86), weight: .medium)).foregroundStyle(fg).padding(.top, tP)
                Spacer(minLength: 2.0)
                Text(key.label).font(.system(size: max(7.0, fs * 0.58), weight: .medium)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.35).padding(.bottom, bP)
            }.padding(.leading, lP).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        case .delete, .ret:
            VStack(alignment: .trailing, spacing: 0.0) {
                Spacer(minLength: 0.0)
                Text(key.label).font(.system(size: max(8.0, fs * 0.70), weight: .medium)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.35).padding(.bottom, bP)
            }.padding(.trailing, lP).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
        default:
            VStack(alignment: .leading, spacing: 0.0) {
                Spacer(minLength: 0.0)
                Text(key.label).font(.system(size: max(8.0, fs * 0.70), weight: .medium)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.35).padding(.bottom, bP)
            }.padding(.leading, lP).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
    private var sym: String { switch key.label { case "control": "⌃"; case "option": "⌥"; case "command": "⌘"; default: "" } }
    private var bg:     Color { active ? (cs == .dark ? Color(white: 0.38) : Color(white: 0.60)) : (cs == .dark ? Color(white: 0.14) : Color(white: 0.93)) }
    private var border: Color { cs == .dark ? .white.opacity(0.06) : .black.opacity(0.06) }
    private var fg:     Color { cs == .dark ? Color(white: 0.94) : Color(white: 0.10) }
}
