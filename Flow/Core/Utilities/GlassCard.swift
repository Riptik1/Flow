//
//  GlassCard.swift
//  Flow
//
//  Created by Riptik Jhajhria on 11/05/26.
//

import SwiftUI

private struct BlurView: UIViewRepresentable {
    var style: UIBlurEffect.Style
    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

struct GlassCard<Content: View>: View {
    let cornerRadius: CGFloat
    let padding: CGFloat
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var scheme
    
    init(cornerRadius: CGFloat = 20, padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            scheme == .dark
                            ? Color(red: 0.09, green: 0.09, blue: 0.13).opacity(0.72)
                            : Color.white.opacity(0.62)
                        )
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(scheme == .dark ? 0.16 : 0.80), location: 0),
                                    .init(color: Color.white.opacity(scheme == .dark ? 0.05 : 0.30), location: 0.35),
                                    .init(color: Color.clear, location: 0.65)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                stops: [
                                    .init(color: Color.white.opacity(scheme == .dark ? 0.32 : 0.90), location: 0),
                                    .init(color: Color.white.opacity(scheme == .dark ? 0.10 : 0.50), location: 0.5),
                                    .init(color: Color.white.opacity(scheme == .dark ? 0.04 : 0.20), location: 1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                }
                .shadow(color: .black.opacity(scheme == .dark ? 0.55 : 0.10), radius: 24, x: 0, y: 12)
                .shadow(color: .black.opacity(scheme == .dark ? 0.22 : 0.05), radius: 5, x: 0, y: 2)
            }
    }
}
