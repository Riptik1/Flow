import SwiftUI

struct SlackStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool
    @Binding var showEmoji: Bool
    let onSend: (FlowMessage) -> Void
    var body: some View {
        HStack(spacing: 4.0) {
            TBBtn(lbl: "⌘K Jump",   w: btnW("⌘K Jump",  btnH, tbH), h: btnH, dark: dark, accent: true) { onSend(.keyPress(keyCode: 40, modifiers: 0x00100000)) }
            TBIconBtn(icon: "chevron.up",   w: btnH * 1.1, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 33, modifiers: 0x00100000)) }
            TBIconBtn(icon: "chevron.down", w: btnH * 1.1, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 30, modifiers: 0x00100000)) }
            TBBtn(lbl: "Mark Read", w: btnW("Mark Read", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 45, modifiers: 0x00120000)) }
            TBIconBtn(icon: "mic.fill", w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 8, modifiers: 0x00120000)) }
            tbLine(dark)
            TBBtn(lbl: "Bold",   w: btnW("Bold",  btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 11, modifiers: 0x00100000)) }
            TBBtn(lbl: "Italic", w: btnW("Italic", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 34, modifiers: 0x00100000)) }
            TBBtn(lbl: "Code",   w: btnW("Code",  btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 8,  modifiers: 0x00120000)) }
            tbLine(dark)
            TBIconBtn(icon: "face.smiling", w: btnH * 1.2, h: btnH, dark: dark) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.12)) { showEmoji = true }
            }
        }
        .frame(height: btnH)
    }
}
