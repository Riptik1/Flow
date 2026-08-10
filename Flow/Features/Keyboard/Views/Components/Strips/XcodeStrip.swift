import SwiftUI

struct XcodeStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool
    let files: [XcodeRecentFile]; let onSend: (FlowMessage) -> Void

    private var indexedFiles: [(Int, XcodeRecentFile)] {
        files.enumerated().map { ($0.offset, $0.element) }
    }

    var body: some View {
        HStack(spacing: 4.0) {
            TBBtn(lbl: "▶ Run",  w: btnW("▶ Run", btnH, tbH),  h: btnH, dark: dark, accent: true) { onSend(.keyPress(keyCode: 45, modifiers: 0x00100000)) }
            TBBtn(lbl: "Stop",   w: btnW("Stop",   btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 47, modifiers: 0x00100000)) }
            TBBtn(lbl: "Build",  w: btnW("Build",  btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 11, modifiers: 0x00100000)) }
            TBBtn(lbl: "Test",   w: btnW("Test",   btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 32, modifiers: 0x00100000)) }
            TBBtn(lbl: "Clean",  w: btnW("Clean",  btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 40, modifiers: 0x00120000)) }
            if !files.isEmpty {
                tbLine(dark)
                ForEach(indexedFiles, id: \.1.id) { idx, file in
                    XcodeFileBtn(file: file, h: btnH, dark: dark) {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSend(.touchBarAction(kind: .openXcodeFile(index: idx)))
                    }
                }
            }
            tbLine(dark)
            TBBtn(lbl: "Quick Open", w: btnW("Quick Open", btnH, tbH), h: btnH, dark: dark, accent: true) { onSend(.keyPress(keyCode: 31, modifiers: 0x00120000)) }
            TBBtn(lbl: "//",   w: btnW("//",  btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 44, modifiers: 0x00100000)) }
            TBBtn(lbl: "Find", w: btnW("Find", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 3,  modifiers: 0x00100000)) }
            TBBtn(lbl: "Jump", w: btnW("Jump", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 38, modifiers: 0x00140000)) }
            TBBtn(lbl: "Undo", w: btnW("Undo", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 6,  modifiers: 0x00100000)) }
            TBBtn(lbl: "Redo", w: btnW("Redo", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 6,  modifiers: 0x00120000)) }
            tbLine(dark)
            TBIconBtn(icon: "sidebar.left",  w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 29, modifiers: 0x00100000)) }
            TBIconBtn(icon: "rectangle.bottomthird.inset.filled", w: btnH * 1.2, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 16, modifiers: 0x00120000)) }
            TBIconBtn(icon: "sidebar.right", w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 29, modifiers: 0x00180000)) }
        }
        .frame(height: btnH)
    }
}

struct XcodeFileBtn: View {
    let file: XcodeRecentFile; let h: CGFloat; let dark: Bool; let onTap: () -> Void

    private var icon: String {
        switch file.ext {
        case "swift": return "swift"
        case "m", "h", "mm", "c": return "c.circle"
        case "json": return "doc.text"
        case "xml", "plist": return "list.bullet.rectangle"
        case "md": return "doc.richtext"
        case "storyboard", "xib": return "rectangle.on.rectangle"
        default: return "doc"
        }
    }
    private var tint: Color {
        switch file.ext {
        case "swift": return .orange
        case "m", "h", "mm", "c": return Color(red: 0.2, green: 0.6, blue: 1.0)
        default: return .secondary
        }
    }
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4.0) {
                Image(systemName: icon).font(.system(size: max(9.0, h * 0.36), weight: .medium))
                    .foregroundStyle(tint).frame(width: 13.0)
                Text(file.name).font(.system(size: max(9.0, h * 0.28), weight: .medium))
                    .foregroundStyle(dark ? Color.white.opacity(0.90) : Color(white: 0.08))
                    .lineLimit(1).frame(maxWidth: 76.0, alignment: .leading)
            }
            .padding(.horizontal, 7.0).frame(height: h)
            .background(RoundedRectangle(cornerRadius: 5.0, style: .continuous)
                .fill(dark ? Color(white: 0.24) : Color(white: 0.66).opacity(0.65)))
        }
        .buttonStyle(TBPressStyle())
    }
}
