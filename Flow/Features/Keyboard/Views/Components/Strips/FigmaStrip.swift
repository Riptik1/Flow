//
//  FigmaStrip.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct FigmaStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool; let onSend: (FlowMessage) -> Void
    var body: some View {
        HStack(spacing: 4.0) {
            TBBtn(lbl: "V", w: btnH, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 9,  modifiers: 0)) }
            TBBtn(lbl: "F", w: btnH, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 3,  modifiers: 0)) }
            TBBtn(lbl: "R", w: btnH, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 15, modifiers: 0)) }
            TBBtn(lbl: "T", w: btnH, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 17, modifiers: 0)) }
            TBBtn(lbl: "P", w: btnH, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 35, modifiers: 0)) }
            tbLine(dark)
            TBIconBtn(icon: "arrow.uturn.backward", w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 6, modifiers: 0x00100000)) }
            TBIconBtn(icon: "arrow.uturn.forward",  w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 6, modifiers: 0x00120000)) }
            TBIconBtn(icon: "doc.on.doc", w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 2,  modifiers: 0x00100000)) }
            TBIconBtn(icon: "rectangle.3.group", w: btnH * 1.2, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 5,  modifiers: 0x00100000)) }
            TBIconBtn(icon: "lock.fill",  w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 37, modifiers: 0x00100000)) }
            tbLine(dark)
            TBBtn(lbl: "Zoom Fit", w: btnW("Zoom Fit", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 22, modifiers: 0x00100000)) }
            TBBtn(lbl: "100%",     w: btnW("100%",     btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 28, modifiers: 0x00100000)) }
        }
        .frame(height: btnH)
    }
}
