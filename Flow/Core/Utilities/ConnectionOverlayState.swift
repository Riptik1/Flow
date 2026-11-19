//
//  ConnectionOverlayState.swift
//  Flow
//
//  Created by Riptik Jhajhria on 24/05/26.
//

import SwiftUI

enum CardOverlayState: Equatable {
    case none
    case disconnected
    case connecting
    case permissionRequired(label: String)
    case premiumRequired

    var isActive: Bool {
        if case .none = self { return false }
        return true
    }

    static func == (lhs: CardOverlayState, rhs: CardOverlayState) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):           return true
        case (.disconnected, .disconnected): return true
        case (.connecting, .connecting):     return true
        case (.permissionRequired(let a), .permissionRequired(let b)): return a == b
        case (.premiumRequired, .premiumRequired): return true
        default: return false
        }
    }
}

struct CardOverlay<Content: View>: View {
    let state: CardOverlayState
    let cornerRadius: CGFloat
    let onAction: () -> Void
    let content: Content

    init(
        state: CardOverlayState,
        cornerRadius: CGFloat = 20,
        onAction: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.state = state
        self.cornerRadius = cornerRadius
        self.onAction = onAction
        self.content = content()
    }

    var body: some View {
        content
            .allowsHitTesting(!state.isActive)
            .overlay {
                if state.isActive {
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(.thinMaterial)
                        overlayContent
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.88)))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: state)
    }

    @ViewBuilder
    private var overlayContent: some View {
        switch state {
        case .none:
            EmptyView()

        case .disconnected:
            Button(action: onAction) {
                HStack(spacing: 7) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Connect")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 22)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(Color.blue)
                        .shadow(color: .blue.opacity(0.4), radius: 10, x: 0, y: 5)
                )
            }
            .buttonStyle(OverlayButtonStyle())

        case .connecting:
            VStack(spacing: 8) {
                ProgressView().tint(.secondary)
                Text("Connecting…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }

        case .permissionRequired(let label):
            Button(action: onAction) {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text(label)
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(Color.orange)
                        .shadow(color: .orange.opacity(0.4), radius: 10, x: 0, y: 5)
                )
            }
            .buttonStyle(OverlayButtonStyle())

        case .premiumRequired:
            Button(action: onAction) {
                HStack(spacing: 7) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Free access ended")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(
                    Capsule()
                        .fill(Color.purple)
                        .shadow(color: .purple.opacity(0.4), radius: 10, x: 0, y: 5)
                )
            }
            .buttonStyle(OverlayButtonStyle())
        }
    }
}

private struct OverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct DeviceSearchSheet: View {
    @ObservedObject private var connection = ConnectionManager.shared
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if connection.state == .connected {
                    connectedView
                } else {
                    searchingView
                }
            }
            .navigationTitle(connection.discoveredPeers.count > 1 ? "Choose a Mac" : "Connect to Mac")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        connection.cancelSearching()
                        onDismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationCornerRadius(24)
        .onAppear {
            if connection.state == .disconnected {
                connection.startSearching()
            }
        }
        .onChange(of: connection.state) { _, newState in
            if newState == .connected {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { onDismiss() }
            }
        }
    }

    private var searchingView: some View {
        VStack(spacing: 28) {
            if connection.discoveredPeers.isEmpty {
                VStack(spacing: 16) {
                    PulsingSearchDot()
                    VStack(spacing: 6) {
                        Text("Searching for Mac")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Make sure Flow is open on your Mac\nand both devices are on the same Wi-Fi")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 32)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Found Nearby")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 20)

                    VStack(spacing: 0) {
                        ForEach(Array(connection.discoveredPeers.enumerated()), id: \.element.id) { index, peer in
                            DiscoveredPeerRow(
                                peer: peer,
                                isLast: index == connection.discoveredPeers.count - 1
                            ) {
                                connection.connect(to: peer)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemGray6))
                    )
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
            }
            Spacer()
        }
    }

    private var connectedView: some View {
        VStack(spacing: 20) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
            }
            VStack(spacing: 6) {
                Text("Connected")
                    .font(.system(size: 20, weight: .bold))
                if let peer = connection.connectedPeer {
                    Text(peer.deviceName)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
    }
}

private struct DiscoveredPeerRow: View {
    let peer: DiscoveredPeer
    let isLast: Bool
    let onConnect: () -> Void
    @ObservedObject private var connection = ConnectionManager.shared
    @ObservedObject private var aliases = DeviceAliasStore.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.primary.opacity(0.7))
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 3) {
                    Text(aliases.displayName(for: peer.deviceName))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(peer.deviceModel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if connection.state == .connecting {
                    ProgressView().tint(.blue)
                } else {
                    Button(action: onConnect) {
                        Text("Connect")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.blue))
                    }
                    .buttonStyle(OverlayButtonStyle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
            .onTapGesture {
                if connection.state != .connecting { onConnect() }
            }

            if !isLast {
                Divider().padding(.leading, 66)
            }
        }
    }
}

private struct PulsingSearchDot: View {
    @State private var scale: CGFloat = 1
    @State private var opacity: Double = 0.6

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.15))
                .frame(width: 72, height: 72)
                .scaleEffect(scale)
                .opacity(opacity)
            Circle()
                .fill(Color.blue.opacity(0.25))
                .frame(width: 52, height: 52)
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.blue)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                scale = 1.25
                opacity = 0.1
            }
        }
    }
}
