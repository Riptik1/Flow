//
//  BrowserStrip.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct BrowserStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool
    let tabs: [TouchBarTab]
    @Binding var showEmoji: Bool
    let onSend: (FlowMessage) -> Void

    private var indexedTabs: [(Int, TouchBarTab)] {
        Array(tabs.prefix(9).enumerated()).map { ($0.offset, $0.element) }
    }

    var body: some View {
        HStack(spacing: 4.0) {
            navButtons
            tbLine(dark)
            addressButtons
            tbLine(dark)
            if !tabs.isEmpty {
                tabButtons
                tbLine(dark)
            }
            mediaButtons
            tbLine(dark)
            extraButtons
        }
        .frame(height: btnH)
    }

    private var mediaButtons: some View {
        HStack(spacing: 4.0) {
            TBIconBtn(icon: "backward.fill",  w: btnH * 1.1, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .mediaPrev)) }
            TBIconBtn(icon: "playpause.fill",  w: btnH * 1.25, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .mediaPlay)) }
            TBIconBtn(icon: "forward.fill",   w: btnH * 1.1, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .mediaNext)) }
            TBIconBtn(icon: "speaker.wave.1.fill", w: btnH * 1.05, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .volumeDown)) }
            TBIconBtn(icon: "speaker.wave.3.fill", w: btnH * 1.05, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .volumeUp)) }
        }
    }

    private var navButtons: some View {
        HStack(spacing: 4.0) {
            TBIconBtn(icon: "chevron.left",    w: btnH * 1.15, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .browserBack)) }
            TBIconBtn(icon: "chevron.right",   w: btnH * 1.15, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .browserForward)) }
            TBIconBtn(icon: "arrow.clockwise", w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 15, modifiers: 0x00100000)) }
            TBIconBtn(icon: "plus",            w: btnH * 1.0,  h: btnH, dark: dark) { onSend(.touchBarAction(kind: .newBrowserTab)) }
            TBIconBtn(icon: "xmark",           w: btnH * 1.0,  h: btnH, dark: dark) { onSend(.touchBarAction(kind: .closeBrowserTab)) }
            TBIconBtn(icon: "arrow.uturn.backward", w: btnH * 1.1, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .reopenClosedTab)) }
        }
    }

    private var addressButtons: some View {
        HStack(spacing: 4.0) {
            TBIconBtn(icon: "magnifyingglass", w: btnH * 1.2, h: btnH, dark: dark, tint: Color(red: 0.38, green: 0.28, blue: 0.92)) {
                onSend(.keyPress(keyCode: 37, modifiers: 0x00100000))
            }
            TBIconBtn(icon: "doc.text.magnifyingglass", w: btnH * 1.2, h: btnH, dark: dark) {
                onSend(.keyPress(keyCode: 3, modifiers: 0x00100000))
            }
        }
    }

    private var tabButtons: some View {
        ForEach(indexedTabs, id: \.1.id) { idx, tab in
            BrowserTabBtn(tab: tab, number: idx + 1, btnH: btnH, dark: dark) {
                onSend(.touchBarAction(kind: .switchBrowserTab(index: idx)))
            }
        }
    }

    private var extraButtons: some View {
        HStack(spacing: 4.0) {
            TBIconBtn(icon: "bookmark",        w: btnH * 1.1, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 2,  modifiers: 0x00100000)) }
            TBIconBtn(icon: "arrow.down.circle", w: btnH * 1.15, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 38, modifiers: 0x00120000)) }
            TBIconBtn(icon: "textformat.size", w: btnH * 1.2, h: btnH, dark: dark) { onSend(.keyPress(keyCode: 37, modifiers: 0x00180000)) }
            TBIconBtn(icon: "face.smiling",    w: btnH * 1.2, h: btnH, dark: dark) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.12)) { showEmoji = true }
            }
        }
    }
}

struct BrowserTabBtn: View {
    let tab: TouchBarTab
    let number: Int
    let btnH: CGFloat
    let dark: Bool
    let onTap: () -> Void

    @ObservedObject private var favicons = FaviconStore.shared
    private var icon: UIImage? { favicons.image(forURL: tab.url) }

    private var shortTitle: String {
        let t = tab.title
        if t.isEmpty || t == "New Tab" { return icon == nil ? "\(number)" : "New Tab" }
        let trimmed = t.count > 12 ? String(t.prefix(11)) + "…" : t
        // With a site logo the logo replaces the number, like the real Touch Bar.
        return icon == nil ? "\(number) \(trimmed)" : trimmed
    }

    private var fgColor: Color {
        if tab.isActive { return dark ? Color.white : Color.black }
        return dark ? Color.white.opacity(0.65) : Color(white: 0.30)
    }

    private var bgColor: Color {
        if tab.isActive { return Color(red: 0.38, green: 0.28, blue: 0.92) }
        return dark ? Color(white: 0.22) : Color(white: 0.70).opacity(0.65)
    }

    private var strokeColor: Color {
        if tab.isActive { return Color.clear }
        return dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4.0) {
                if let icon {
                    Image(uiImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: btnH * 0.46, height: btnH * 0.46)
                        .clipShape(RoundedRectangle(cornerRadius: 3.0, style: .continuous))
                }
                Text(shortTitle)
                    .font(.system(size: max(9.0, btnH * 0.34), weight: tab.isActive ? .bold : .medium, design: .rounded))
                    .foregroundStyle(fgColor)
                    .lineLimit(1)
            }
                .padding(.horizontal, 5.0)
                .frame(height: btnH)
                .background(
                    RoundedRectangle(cornerRadius: 5.0, style: .continuous)
                        .fill(bgColor)
                        .overlay(RoundedRectangle(cornerRadius: 5.0, style: .continuous)
                            .strokeBorder(strokeColor, lineWidth: 0.6))
                )
        }
        .buttonStyle(TBPressStyle())
    }
}
