//
//  EmojiStrip.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

private struct EmojiEntry: Identifiable {
    let id: Int
    let emoji: String
}

struct EmojiStrip: View {
    let btnH: CGFloat
    let dark: Bool
    let onPick: (String) -> Void
    let onClose: () -> Void

    private var entries: [EmojiEntry] {
        KeyboardLayout.emojiList.enumerated().map { EmojiEntry(id: $0.offset, emoji: $0.element) }
    }

    var body: some View {
        HStack(spacing: 4.0) {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: max(9.0, btnH * 0.38), weight: .semibold))
                    .foregroundStyle(dark ? Color.white.opacity(0.80) : Color(white: 0.20))
                    .frame(width: btnH * 1.1, height: btnH)
                    .background(RoundedRectangle(cornerRadius: 5.0, style: .continuous)
                        .fill(dark ? Color(white: 0.24) : Color(white: 0.62).opacity(0.55)))
            }
            .buttonStyle(TBPressStyle())

            tbLine(dark)

            ForEach(entries) { entry in
                let captured = entry.emoji
                Button {
                    onPick(captured)
                } label: {
                    Text(captured)
                        .font(.system(size: max(12.0, btnH * 0.60)))
                        .frame(width: btnH * 1.2, height: btnH)
                        .background(RoundedRectangle(cornerRadius: 5.0, style: .continuous)
                            .fill(dark ? Color(white: 0.22) : Color(white: 0.70).opacity(0.70)))
                }
                .buttonStyle(TBPressStyle())
            }
        }
        .frame(height: btnH)
    }
}
