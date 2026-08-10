//
//  FinderStrip.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct FinderStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool; let onSend: (FlowMessage) -> Void
    var body: some View {
        HStack(spacing: 4.0) {
            TBBtn(lbl: "New Folder", w: btnW("New Folder", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 45, modifiers: 0x00120000)) }
            TBBtn(lbl: "Rename",     w: btnW("Rename",     btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 36, modifiers: 0)) }
            TBIconBtn(icon: "magnifyingglass",  w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 3,  modifiers: 0x00100000)) }
            TBIconBtn(icon: "info.circle",      w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 18, modifiers: 0x00100000)) }
            TBIconBtn(icon: "eye",              w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 49, modifiers: 0)) }
            TBIconBtn(icon: "doc.on.clipboard", w: btnH * 1.2, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 8, modifiers: 0x00120000)) }
            TBIconBtn(icon: "trash",            w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 51, modifiers: 0x00100000)) }
            tbLine(dark)
            TBIconBtn(icon: "square.grid.2x2",  w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 18, modifiers: 0x00140000)) }
            TBIconBtn(icon: "list.bullet",      w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 19, modifiers: 0x00140000)) }
            TBIconBtn(icon: "square.split.2x1", w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 20, modifiers: 0x00140000)) }
            TBIconBtn(icon: "arrow.up.left.and.arrow.down.right", w: btnH * 1.2, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 3, modifiers: 0x00120000)) }
        }
        .frame(height: btnH)
    }
}
