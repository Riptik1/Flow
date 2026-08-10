//
//  CardsView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 11/05/26.
//

import SwiftUI

struct KeyboardCard: View {
    var body: some View {
        NavigationLink {
            MacKeyboardView()
                .navigationBarBackButtonHidden(true)
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Keyboard")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("with Touch Bar")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    Image("keyboard")
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(1.2)
                        .frame(height: 95)
                        .padding(.bottom, -24)
                        .shadow(color: .blue.opacity(0.12), radius: 10, x: 0, y: 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct FilesCard: View {
    var body: some View {
        NavigationLink {
            FileView()
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Files")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text("Browse Mac files")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)

                    HStack {
                        Spacer()
                        Image(systemName: "folder.fill")
                            .font(.system(size: 60, weight: .regular))
                            .foregroundStyle(.blue)
                            .shadow(color: .blue.opacity(0.23), radius: 12, x: 2, y: 6)
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct TrackpadCard: View {
    var isAccessGranted: Bool = true
    var onRequestAccess: () -> Void = {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    var body: some View {
        CardOverlay(
            state: isAccessGranted ? .none : .permissionRequired(label: "Enable Trackpad Access"),
            onAction: onRequestAccess
        ) {
            NavigationLink {
                TrackpadView()
                    .navigationBarBackButtonHidden(true)
            } label: {
                GlassCard {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trackpad")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)

                        Text("Swipe, haptics and gesture")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Image("trackpad")
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(1.1)
                            .shadow(color: .blue.opacity(0.11), radius: 12, x: 2, y: 6)
                            .padding(.bottom, -25)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .buttonStyle(CardButtonStyle())
        }
    }
}

struct DeviceInfoCard: View {
    @StateObject private var connection = FlowConnectionRepository.shared
    @State private var showSearchSheet = false

    var body: some View {
        CardOverlay(state: cardOverlayState, onAction: handleConnectTap) {
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(connection.state == .connected ? Color.green : Color.secondary.opacity(0.35))
                                .frame(width: 7, height: 7)
                                .shadow(
                                    color: connection.state == .connected ? Color.green.opacity(0.7) : .clear,
                                    radius: 3, x: 0, y: 0
                                )

                            Text(connection.state == .connected ? "Connected to" : "No Mac Connected")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Text(connection.connectedPeer?.deviceName ?? "MacBook")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(connection.state == .connected ? .primary : .tertiary)
                            .minimumScaleFactor(0.8)
                            .lineLimit(3)
                    }
                    .padding(.top, -25)

                    Spacer()

                    Image("macbook")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 185, height: 115)
                        .opacity(connection.state == .connected ? 1 : 0.3)
                        .shadow(
                            color: .blue.opacity(connection.state == .connected ? 0.13 : 0),
                            radius: 12, x: 2, y: 6
                        )
                        .padding(.trailing, -33)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .padding(.vertical, -26)
            }
        }
        .sheet(isPresented: $showSearchSheet) {
            DeviceSearchSheet(onDismiss: { showSearchSheet = false })
        }
    }

    private var cardOverlayState: CardOverlayState {
        switch connection.state {
        case .disconnected:          return .disconnected
        case .searching, .connecting: return .connecting
        case .connected:             return .none
        }
    }

    private func handleConnectTap() {
        guard case .disconnected = connection.state else { return }
        connection.startSearching()
        showSearchSheet = true
    }

    private func batterySystemImage(for level: Float) -> String {
        guard level >= 0 else { return "battery.0" }
        switch level {
        case ..<10: return "battery.0"
        case ..<25: return "battery.25"
        case ..<50: return "battery.50"
        case ..<75: return "battery.75"
        default:    return "battery.100"
        }
    }

    private func batteryColor(for level: Float) -> Color {
        guard level >= 0 else { return .secondary }
        if level < 20 { return .red }
        if level < 50 { return .yellow }
        return .green
    }

    private func batteryLabel(for level: Float) -> String {
        guard level >= 0 else { return "–" }
        return "\(Int(level))%"
    }
}

private struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0), value: configuration.isPressed)
    }
}
