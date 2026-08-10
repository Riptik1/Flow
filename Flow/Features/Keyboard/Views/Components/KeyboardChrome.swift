//
//  KeyboardChrome.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct KBCornerHintDot: View {
    let isIPad: Bool
    @Environment(\.colorScheme) private var cs

    private var dotColor: Color {
        cs == .dark ? Color.white.opacity(0.30) : Color.black.opacity(0.22)
    }

    var body: some View {
        Circle()
            .fill(dotColor)
            .frame(width: 36.0, height: 36.0)
            .offset(x: isIPad ? -6.0 : 1.0, y: isIPad ? -32.0 : -22.0)
    }
}

struct KBBackButton: View {
    let action: () -> Void
    @Environment(\.colorScheme) private var cs
    private var pad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var strokeC: Color {
        cs == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.10)
    }

    private var shadowC: Color {
        Color.black.opacity(cs == .dark ? 0.45 : 0.15)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5.0) {
                Image(systemName: "chevron.left")
                    .font(.system(size: pad ? 16.0 : 14.0, weight: .semibold))
                Text("Back")
                    .font(.system(size: pad ? 17.0 : 15.0, weight: .semibold))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, pad ? 20.0 : 16.0)
            .frame(height: pad ? 52.0 : 44.0)
            .background(
                Capsule().fill(Material.ultraThinMaterial)
                    .overlay(Capsule().stroke(strokeC, lineWidth: 0.8))
                    .shadow(color: shadowC, radius: 12.0, x: 0.0, y: 3.0)
            )
        }
        .buttonStyle(.plain)
    }
}
