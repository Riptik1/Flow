//
//  MailStrip.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct MailStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool
    @Binding var showEmoji: Bool
    let onSend: (FlowMessage) -> Void
    var body: some View {
        HStack(spacing: 4.0) {
            TBBtn(lbl: "✉ New",     w: btnW("✉ New",    btnH, tbH), h: btnH, dark: dark, accent: true) { onSend(.keyPress(keyCode: 45, modifiers: 0x00100000)) }
            TBBtn(lbl: "Reply",     w: btnW("Reply",    btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 15, modifiers: 0x00100000)) }
            TBBtn(lbl: "Reply All", w: btnW("Reply All", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 15, modifiers: 0x00120000)) }
            TBBtn(lbl: "Forward",   w: btnW("Forward",  btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 9,  modifiers: 0x00100000)) }
            TBBtn(lbl: "⬆ Send",    w: btnW("⬆ Send",   btnH, tbH), h: btnH, dark: dark, accent: true) { onSend(.keyPress(keyCode: 36, modifiers: 0x00100000)) }
            tbLine(dark)
            TBIconBtn(icon: "magnifyingglass", w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 37, modifiers: 0x00100000)) }
            TBIconBtn(icon: "flag",       w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 37, modifiers: 0x00120000)) }
            TBIconBtn(icon: "envelope.badge", w: btnH * 1.2, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 32, modifiers: 0x00120000)) }
            TBIconBtn(icon: "trash",      w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 51, modifiers: 0)) }
            TBIconBtn(icon: "archivebox", w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 8,  modifiers: 0x00100000)) }
            tbLine(dark)
            TBIconBtn(icon: "face.smiling", w: btnH * 1.2, h: btnH, dark: dark) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.12)) { showEmoji = true }
            }
        }
        .frame(height: btnH)
    }
}
