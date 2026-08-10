//
//  FnStrip.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct FnStrip: View {
    let btnH: CGFloat; let tbH: CGFloat; let dark: Bool
    let onSend: (FlowMessage) -> Void

    var body: some View {
        HStack(spacing: 4.0) {
            ForEach(KeyboardLayout.functionKeyPairs, id: \.0) { lbl, code in
                TBBtn(lbl: lbl, w: max(btnH, tbH * 0.9), h: btnH, dark: dark) {
                    onSend(.keyPress(keyCode: code, modifiers: 0x00800000))
                }
            }
        }
        .frame(height: btnH)
    }
}
