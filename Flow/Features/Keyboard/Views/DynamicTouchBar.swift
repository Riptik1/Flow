//
//  DynamicTouchBar.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct DynamicTouchBar: View {
    let tbH: CGFloat
    let fnOn: Bool
    let isMuted: Bool
    let frontApp: AppContext
    let browserTabs: [TouchBarTab]
    let xcodeFiles: [XcodeRecentFile]
    @Binding var showEmoji: Bool
    let onFnToggle: () -> Void
    let onMuteToggle: () -> Void
    let onSend: (FlowMessage) -> Void
    let onType: (String) -> Void

    @Environment(\.colorScheme) private var cs
    private var dark: Bool  { cs == .dark }
    private var cr: CGFloat { min(10.0, tbH * 0.36) }
    private var btnH: CGFloat { tbH * 0.72 }

    private var fillC: Color {
        dark ? Color(white: 0.11) : Color(white: 0.82)
    }

    private var shadowC: Color {
        Color.black.opacity(dark ? 0.50 : 0.13)
    }

    private var strokeColors: [Color] {
        dark ? [Color.white.opacity(0.14), Color.white.opacity(0.03)]
             : [Color.white.opacity(0.85), Color(white: 0.55).opacity(0.25)]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .fill(fillC)
                .shadow(color: shadowC, radius: dark ? 12.0 : 6.0, x: 0.0, y: dark ? 5.0 : 3.0)
            RoundedRectangle(cornerRadius: cr, style: .continuous)
                .strokeBorder(LinearGradient(colors: strokeColors, startPoint: .top, endPoint: .bottom), lineWidth: 0.6)

            HStack(spacing: 0.0) {
                escBtn.padding(.leading, 6.0)
                tbLine(dark).padding(.horizontal, 5.0)
                ScrollView(.horizontal, showsIndicators: false) {
                    activeStrip
                        .padding(.horizontal, 4.0)
                }
                .frame(maxWidth: .infinity)
                tbLine(dark).padding(.horizontal, 5.0)
                lockBtn.padding(.trailing, 6.0)
            }
        }
        .frame(height: tbH)
        .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
        .animation(.easeInOut(duration: 0.18), value: fnOn)
        .animation(.easeInOut(duration: 0.20), value: frontApp)
        .animation(.easeInOut(duration: 0.15), value: showEmoji)
    }

    @ViewBuilder
    private var activeStrip: some View {
        if showEmoji {
            EmojiStrip(btnH: btnH, dark: dark,
                onPick: { emoji in
                    onSend(.typeText(text: emoji))
                },
                onClose: {
                    withAnimation(.easeOut(duration: 0.12)) { showEmoji = false }
                })
        } else if fnOn {
            FnStrip(btnH: btnH, tbH: tbH, dark: dark, onSend: onSend)
        } else {
            appSpecificStrip
        }
    }

    @ViewBuilder
    private var appSpecificStrip: some View {
        if frontApp.isBrowser {
            BrowserStrip(btnH: btnH, tbH: tbH, dark: dark, tabs: browserTabs,
                         showEmoji: $showEmoji, onSend: onSend)
        } else if frontApp.isXcode {
            XcodeStrip(btnH: btnH, tbH: tbH, dark: dark, files: xcodeFiles, onSend: onSend)
        } else if frontApp.isVSCode {
            VSCodeStrip(btnH: btnH, tbH: tbH, dark: dark, onSend: onSend)
        } else if frontApp.isTerminal {
            TerminalStrip(btnH: btnH, tbH: tbH, dark: dark, onSend: onSend, onType: onType)
        } else if frontApp.isMail {
            MailStrip(btnH: btnH, tbH: tbH, dark: dark, showEmoji: $showEmoji, onSend: onSend)
        } else {
            otherAppStrip
        }
    }

    @ViewBuilder
    private var otherAppStrip: some View {
        if frontApp.isMediaApp {
            MediaStrip(btnH: btnH, tbH: tbH, dark: dark, onSend: onSend)
        } else if frontApp.isNotes || frontApp.isPages {
            NotesStrip(btnH: btnH, tbH: tbH, dark: dark, showEmoji: $showEmoji, onSend: onSend)
        } else if frontApp.isFinder {
            FinderStrip(btnH: btnH, tbH: tbH, dark: dark, onSend: onSend)
        } else if frontApp.isSlack {
            SlackStrip(btnH: btnH, tbH: tbH, dark: dark, showEmoji: $showEmoji, onSend: onSend)
        } else if frontApp.isFigma {
            FigmaStrip(btnH: btnH, tbH: tbH, dark: dark, onSend: onSend)
        } else {
            DefaultStrip(btnH: btnH, tbH: tbH, dark: dark, isMuted: isMuted,
                         showEmoji: $showEmoji, onMuteToggle: onMuteToggle, onSend: onSend)
        }
    }

    private var escBtn: some View {
        Button {
            onSend(.keyPress(keyCode: 53, modifiers: 0))
        } label: {
            Text("esc")
                .font(.system(size: max(10.0, tbH * 0.33), weight: .semibold, design: .rounded))
                .foregroundStyle(dark ? Color.white.opacity(0.92) : Color(white: 0.08))
                .frame(width: max(44.0, tbH * 1.55), height: btnH)
                .background(RoundedRectangle(cornerRadius: 5.0, style: .continuous)
                    .fill(dark ? Color(white: 0.22) : Color(white: 0.58).opacity(0.55)))
        }
        .buttonStyle(TBPressStyle())
    }

    private var lockBtn: some View {
        TBIconBtn(icon: "lock.fill", w: btnH * 1.1, h: btnH, dark: dark) {
            onSend(.touchBarAction(kind: .lockScreen))
        }
    }
}
