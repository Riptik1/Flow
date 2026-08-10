//
//  TerminalStrip.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct TerminalStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool
    let onSend: (FlowMessage) -> Void; let onType: (String) -> Void
    var body: some View {
        HStack(spacing: 4.0) {
            TBBtn(lbl: "⌃C",      w: btnW("⌃C",     btnH, tbH), h: btnH, dark: dark, accent: true) { onSend(.keyPress(keyCode: 8,  modifiers: 0x00040000)) }
            TBBtn(lbl: "⌃D",      w: btnW("⌃D",     btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 2,  modifiers: 0x00040000)) }
            TBBtn(lbl: "⌃Z",      w: btnW("⌃Z",     btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 6,  modifiers: 0x00040000)) }
            TBBtn(lbl: "⌃R",      w: btnW("⌃R",     btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 15, modifiers: 0x00040000)) }
            TBBtn(lbl: "⌃L",      w: btnW("⌃L",     btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 37, modifiers: 0x00040000)) }
            tbLine(dark)
            TBBtn(lbl: "New Tab",  w: btnW("New Tab", btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 17, modifiers: 0x00100000)) }
            TBBtn(lbl: "Split",    w: btnW("Split",   btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 2,  modifiers: 0x00100000)) }
            TBBtn(lbl: "Find",     w: btnW("Find",    btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 3,  modifiers: 0x00100000)) }
            TBBtn(lbl: "Clear",    w: btnW("Clear",   btnH, tbH), h: btnH, dark: dark) { onSend(.keyPress(keyCode: 37, modifiers: 0x00100000)) }
            tbLine(dark)
            TBBtn(lbl: "ls",      w: btnW("ls",     btnH, tbH), h: btnH, dark: dark) { onType("ls -la\n") }
            TBBtn(lbl: "cd ~",    w: btnW("cd ~",   btnH, tbH), h: btnH, dark: dark) { onType("cd ~\n") }
            TBBtn(lbl: "pwd",     w: btnW("pwd",    btnH, tbH), h: btnH, dark: dark) { onType("pwd\n") }
            TBBtn(lbl: "clear",   w: btnW("clear",  btnH, tbH), h: btnH, dark: dark) { onType("clear\n") }
            TBBtn(lbl: "git st",  w: btnW("git st", btnH, tbH), h: btnH, dark: dark) { onType("git status\n") }
            TBBtn(lbl: "git log", w: btnW("git log", btnH, tbH), h: btnH, dark: dark) { onType("git log --oneline\n") }
            TBBtn(lbl: "git diff", w: btnW("git diff", btnH, tbH), h: btnH, dark: dark) { onType("git diff\n") }
            tbLine(dark)
            TBIconBtn(icon: "doc.text.magnifyingglass", w: btnH * 1.25, h: btnH, dark: dark) { onSend(.startLogStream) }
            TBIconBtn(icon: "stop.circle",              w: btnH * 1.1,  h: btnH, dark: dark) { onSend(.stopLogStream) }
        }
        .frame(height: btnH)
    }
}
