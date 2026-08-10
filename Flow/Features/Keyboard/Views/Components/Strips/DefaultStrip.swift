//
//  DefaultStrip.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct DefaultStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool
    let isMuted: Bool
    @Binding var showEmoji: Bool
    let onMuteToggle: () -> Void
    let onSend: (FlowMessage) -> Void

    var body: some View {
        HStack(spacing: 4.0) {
            TBSlider(icon0: "sun.min", icon1: "sun.max.fill", tbH: tbH, dark: dark, initial: 0.75,
                     onDown: { onSend(.touchBarAction(kind: .brightnessDown)) },
                     onUp:   { onSend(.touchBarAction(kind: .brightnessUp)) })
            tbLine(dark)
            TBIconBtn(icon: "magnifyingglass", w: btnH * 1.15, h: btnH, dark: dark) {
                onSend(.touchBarAction(kind: .spotlight))
            }
            TBIconBtn(icon: "square.grid.3x3.fill", w: btnH * 1.15, h: btnH, dark: dark) {
                onSend(.touchBarAction(kind: .launchpad))
            }
            TBIconBtn(icon: "rectangle.3.group", w: btnH * 1.2, h: btnH, dark: dark) {
                onSend(.touchBarAction(kind: .missionControl))
            }
            TBIconBtn(icon: "macwindow.on.rectangle", w: btnH * 1.2, h: btnH, dark: dark) {
                onSend(.touchBarAction(kind: .appWindows))
            }
            TBIconBtn(icon: "menubar.dock.rectangle", w: btnH * 1.2, h: btnH, dark: dark) {
                onSend(.touchBarAction(kind: .showDesktop))
            }
            tbLine(dark)
            TBIconBtn(icon: "backward.fill",  w: btnH * 1.1, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .mediaPrev)) }
            TBIconBtn(icon: "playpause.fill",  w: btnH * 1.3, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .mediaPlay)) }
            TBIconBtn(icon: "forward.fill",   w: btnH * 1.1, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .mediaNext)) }
            tbLine(dark)
            TBIconBtn(icon: "speaker.wave.1.fill", w: btnH * 1.1, h: btnH, dark: dark) {
                onSend(.touchBarAction(kind: .volumeDown))
            }
            TBIconBtn(
                icon: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                w: btnH * 1.15, h: btnH, dark: dark, tint: isMuted ? .red : nil
            ) { onMuteToggle() }
            TBIconBtn(icon: "speaker.wave.3.fill", w: btnH * 1.1, h: btnH, dark: dark) {
                onSend(.touchBarAction(kind: .volumeUp))
            }
            tbLine(dark)
            TBIconBtn(icon: "face.smiling", w: btnH * 1.2, h: btnH, dark: dark) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeOut(duration: 0.12)) { showEmoji = true }
            }
        }
        .frame(height: btnH)
    }
}
