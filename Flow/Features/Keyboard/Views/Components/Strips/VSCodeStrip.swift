import SwiftUI

struct VSCodeStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool; let onSend: (FlowMessage) -> Void
    var body: some View {
        HStack(spacing: 4.0) {
            TBBtn(lbl: "▶ Run",    w: btnW("▶ Run",   btnH, tbH), h: btnH, dark: dark, accent: true) { onSend(.keyPress(keyCode: 45, modifiers: 0x00100000)) }
            TBBtn(lbl: "Terminal", w: btnW("Terminal", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 54, modifiers: 0x00100000)) }
            TBBtn(lbl: "Find",     w: btnW("Find",     btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 3,  modifiers: 0x00100000)) }
            TBBtn(lbl: "Palette",  w: btnW("Palette",  btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 35, modifiers: 0x00120000)) }
            TBBtn(lbl: "Go to File", w: btnW("Go to File", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 35, modifiers: 0x00100000)) }
            tbLine(dark)
            TBIconBtn(icon: "sidebar.left",  w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 11, modifiers: 0x00100000)) }
            TBIconBtn(icon: "square.split.2x1", w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 0,  modifiers: 0x00100000)) }
            tbLine(dark)
            TBBtn(lbl: "//",   w: btnW("//",  btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 44, modifiers: 0x00100000)) }
            TBBtn(lbl: "Undo", w: btnW("Undo", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 6,  modifiers: 0x00100000)) }
            TBBtn(lbl: "Redo", w: btnW("Redo", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 6,  modifiers: 0x00120000)) }
        }
        .frame(height: btnH)
    }
}
