//
//  QuickActionsView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 11/05/26.
//

import SwiftUI

private struct QuickActionButton: View {
    let action: QuickAction
    let onTap: () -> Void
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [action.topColor, action.bottomColor],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .white.opacity(isPressed ? 0.08 : 0.30), location: 0),
                                .init(color: .white.opacity(isPressed ? 0.02 : 0.08), location: 0.45),
                                .init(color: .clear, location: 0.75)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(isPressed ? 0.10 : 0.45),
                                .white.opacity(isPressed ? 0.04 : 0.14)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )

                if isPressed {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.18))
                }

                Image(systemName: action.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.28), radius: 3, x: 0, y: 2)
                    .scaleEffect(isPressed ? 0.88 : 1.0)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: 58, height: 58)
            .shadow(
                color: action.bottomColor.opacity(isPressed ? 0.20 : 0.55),
                radius: isPressed ? 4 : 12,
                x: 0,
                y: isPressed ? 2 : 6
            )
            .offset(y: isPressed ? 2 : 0)

            Text(action.title)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 70)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.16, dampingFraction: 0.62)) { isPressed = true }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.72)) { isPressed = false }
            }
            onTap()
        }
    }
}

struct QuickActionsView: View {
    let style: Style
    var isMuted     : Bool          = false
    var onLaunchApp : (() -> Void)? = nil
    var onWorkflows : (() -> Void)? = nil
    var onTerminal  : (() -> Void)? = nil
    var onClipboard : (() -> Void)? = nil
    var onSearch    : (() -> Void)? = nil
    var onMute      : (() -> Void)? = nil
    var onLock      : (() -> Void)? = nil
    var onShutDown  : (() -> Void)? = nil
    var onFireToast : (ToastPresentation) -> Void = { _ in }

    enum Style { case grid, row }

    private var muteTitle: String      { isMuted ? "Unmute Mac"          : "Mute Mac" }
    private var muteIcon: String       { isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill" }
    private var muteTopColor: Color    { isMuted ? Color(red: 0.10, green: 0.65, blue: 0.40) : Color(red: 0.90, green: 0.20, blue: 0.45) }
    private var muteBottomColor: Color { isMuted ? Color(red: 0.04, green: 0.44, blue: 0.24) : Color(red: 0.70, green: 0.08, blue: 0.30) }

    private var allActions: [QuickAction] {[
        QuickAction(id: .launchApp, title: "Launch App", icon: "app.fill",
            topColor: Color(red: 0.75, green: 0.20, blue: 0.95),
            bottomColor: Color(red: 0.55, green: 0.10, blue: 0.80), kind: .launchApp),
        QuickAction(id: .workflows, title: "Workflows", icon: "square.3.layers.3d",
            topColor: Color(red: 0.20, green: 0.50, blue: 0.95),
            bottomColor: Color(red: 0.10, green: 0.30, blue: 0.80), kind: .workflows),
        QuickAction(id: .terminal, title: "Terminal", icon: "terminal.fill",
            topColor: Color(red: 0.10, green: 0.65, blue: 0.75),
            bottomColor: Color(red: 0.05, green: 0.42, blue: 0.58), kind: .terminal),
        QuickAction(id: .clipboard, title: "Clipboard", icon: "list.bullet.clipboard",
            topColor: Color(red: 0.18, green: 0.72, blue: 0.38),
            bottomColor: Color(red: 0.08, green: 0.52, blue: 0.25), kind: .clipboard),
        QuickAction(id: .search, title: "Search", icon: "magnifyingglass",
            topColor: Color(red: 0.95, green: 0.28, blue: 0.28),
            bottomColor: Color(red: 0.78, green: 0.10, blue: 0.10), kind: .search),
        QuickAction(id: .muteMac, title: muteTitle, icon: muteIcon,
            topColor: muteTopColor, bottomColor: muteBottomColor, kind: .muteMac),
        QuickAction(id: .lockMac, title: "Lock Mac", icon: "lock.fill",
            topColor: Color(red: 0.95, green: 0.60, blue: 0.10),
            bottomColor: Color(red: 0.80, green: 0.40, blue: 0.00), kind: .lockMac),
        QuickAction(id: .shutDown, title: "Shut Down", icon: "power",
            topColor: Color(red: 0.10, green: 0.72, blue: 0.65),
            bottomColor: Color(red: 0.05, green: 0.50, blue: 0.48), kind: .shutDown)
    ]}

    var body: some View {
        GlassCard(padding: 20) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Quick Actions")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)

                if style == .grid {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4),
                        spacing: 20
                    ) {
                        ForEach(allActions) { action in
                            QuickActionButton(action: action) { handleTap(action) }
                        }
                    }
                } else {
                    HStack(spacing: 0) {
                        ForEach(allActions) { action in
                            QuickActionButton(action: action) { handleTap(action) }
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func handleTap(_ action: QuickAction) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        switch action.kind {
        case .launchApp:  onLaunchApp?()
        case .workflows:  onWorkflows?()
        case .terminal:   onTerminal?()
        case .clipboard:  onClipboard?()
        case .search:     onSearch?()
        case .muteMac:
            onMute?()
            let willBeMuted = !isMuted
            onFireToast(ToastPresentation(
                message: willBeMuted ? "Mac Muted" : "Mac Unmuted",
                icon:  willBeMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                color: willBeMuted ? Color(red: 0.90, green: 0.20, blue: 0.45) : Color(red: 0.10, green: 0.65, blue: 0.40)
            ))
        case .lockMac:
            onLock?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                onFireToast(ToastPresentation(message: "Mac Locked", icon: "lock.fill", color: Color(red: 0.95, green: 0.60, blue: 0.10)))
            }
        case .shutDown:
            confirmShutdown()
        }
    }

    private func confirmShutdown() {
        let alert = UIAlertController(
            title: "Shut Down Mac?",
            message: "Flow will try to quit all open apps before shutting down.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Shut Down", style: .destructive) { _ in
            onShutDown?()
            onFireToast(ToastPresentation(message: "Shutting Down…", icon: "power", color: Color(red: 0.10, green: 0.72, blue: 0.65)))
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                onFireToast(ToastPresentation(message: "Shut Down Complete", icon: "checkmark.circle.fill", color: Color(red: 0.18, green: 0.86, blue: 0.40)))
            }
        })
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root  = scene.windows.first?.rootViewController {
            root.present(alert, animated: true)
        }
    }
}

#Preview("Grid") {
    QuickActionsView(style: .grid, isMuted: false).padding()
}

struct ActionToast: View {
    let message: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.10), lineWidth: 0.6)
            }
        )
        .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 10)
    }
}
