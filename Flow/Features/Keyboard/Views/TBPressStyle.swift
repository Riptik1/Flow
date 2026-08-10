import SwiftUI

struct TBPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.easeOut(duration: 0.06), value: configuration.isPressed)
    }
}

func tbLine(_ dark: Bool) -> some View {
    Rectangle()
        .fill(dark ? Color.white.opacity(0.18) : Color.black.opacity(0.18))
        .frame(width: 1.0, height: 20.0)
        .padding(.horizontal, 3.0)
}

func btnW(_ label: String, _ h: CGFloat, _ tbH: CGFloat) -> CGFloat {
    max(h, CGFloat(label.count) * max(6.5, tbH * 0.21) + tbH * 0.40)
}

struct TBBtn: View {
    let lbl: String; let w: CGFloat; let h: CGFloat; let dark: Bool
    var accent: Bool = false; let action: () -> Void

    private var fgColor: Color {
        if accent { return Color.white }
        return dark ? Color.white.opacity(0.90) : Color(white: 0.10)
    }

    private var bgColor: Color {
        if accent { return Color(red: 0.38, green: 0.28, blue: 0.92) }
        return dark ? Color(white: 0.28) : Color(white: 0.60).opacity(0.55)
    }

    var body: some View {
        Button(action: action) {
            Text(lbl)
                .font(.system(size: max(9.0, h * 0.33), weight: .medium, design: .rounded))
                .foregroundStyle(fgColor)
                .lineLimit(1).minimumScaleFactor(0.5)
                .frame(width: w, height: h)
                .background(RoundedRectangle(cornerRadius: 5.0, style: .continuous).fill(bgColor))
        }
        .buttonStyle(TBPressStyle())
    }
}

struct TBIconBtn: View {
    let icon: String; let w: CGFloat; let h: CGFloat; let dark: Bool
    var tint: Color? = nil; let action: () -> Void

    private var fgColor: Color {
        if let t = tint { return t }
        return dark ? Color.white.opacity(0.88) : Color(white: 0.10)
    }

    private var bgColor: Color {
        if let t = tint { return t.opacity(dark ? 0.25 : 0.15) }
        return dark ? Color(white: 0.28) : Color(white: 0.60).opacity(0.55)
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: max(9.0, h * 0.40), weight: .medium))
                .foregroundStyle(fgColor)
                .frame(width: w, height: h)
                .background(RoundedRectangle(cornerRadius: 5.0, style: .continuous).fill(bgColor))
        }
        .buttonStyle(TBPressStyle())
    }
}
