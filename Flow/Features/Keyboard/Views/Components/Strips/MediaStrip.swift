//
//  MediaStrip.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct MediaStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool; let onSend: (FlowMessage) -> Void
    var body: some View {
        HStack(spacing: 4.0) {
            TBIconBtn(icon: "backward.fill", w: btnH * 1.2, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .mediaPrev)) }
            TBIconBtn(icon: "playpause.fill", w: btnH * 1.4, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .mediaPlay)) }
            TBIconBtn(icon: "forward.fill",  w: btnH * 1.2, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .mediaNext)) }
            tbLine(dark)
            TBIconBtn(icon: "speaker.wave.1.fill", w: btnH * 1.1, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .volumeDown)) }
            TBIconBtn(icon: "speaker.wave.3.fill", w: btnH * 1.1, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .volumeUp)) }
            tbLine(dark)
            TBIconBtn(icon: "sun.min", w: btnH * 1.1, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .brightnessDown)) }
            TBIconBtn(icon: "sun.max.fill", w: btnH * 1.1, h: btnH, dark: dark) { onSend(.touchBarAction(kind: .brightnessUp)) }
        }
        .frame(height: btnH)
    }
}
