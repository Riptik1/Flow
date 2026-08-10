import SwiftUI

struct NotesStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool
    @Binding var showEmoji: Bool
    let onSend: (FlowMessage) -> Void
    var body: some View {
        HStack(spacing: 4.0) {
            TBIconBtn(icon: "square.and.pencil", w: btnH * 1.2, h: btnH, dark: dark, tint: Color(red: 1.0, green: 0.78, blue: 0.0)) { onSend(.keyPress(keyCode: 45, modifiers: 0x00100000)) }
            TBIconBtn(icon: "magnifyingglass",    w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 37, modifiers: 0x00100000)) }
            TBIconBtn(icon: "pin",                w: btnH * 1.1, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 35, modifiers: 0x00120000)) }
            tbLine(dark)
            TBBtn(lbl: "B", w: btnH * 1.1, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 11, modifiers: 0x00100000)) }
            TBBtn(lbl: "I", w: btnH * 1.1, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 34, modifiers: 0x00100000)) }
            TBBtn(lbl: "U", w: btnH * 1.1, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 32, modifiers: 0x00100000)) }
            tbLine(dark)
            TBBtn(lbl: "Title",     w: btnW("Title",    btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 36, modifiers: 0x00120000)) }
            TBBtn(lbl: "Heading",   w: btnW("Heading",  btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 4,  modifiers: 0x00100000)) }
            TBBtn(lbl: "List",      w: btnW("List",     btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 37, modifiers: 0x00180000)) }
            TBBtn(lbl: "Checklist", w: btnW("Checklist", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 37, modifiers: 0x00900000)) }
            tbLine(dark)
            TBIconBtn(icon: "face.smiling", w: btnH * 1.2, h: btnH, dark: dark) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.12)) { showEmoji = true }
            }
        }
        .frame(height: btnH)
    }
}
