//
//  FlowMenuBarView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 01/06/26.
//

import SwiftUI
import AppKit
import ApplicationServices
import IOKit.hid
import ServiceManagement

struct FlowMenuBarView: View {
    @StateObject private var connection = FlowConnectionRepository.shared
    @StateObject private var pairing = RemotePairingViewModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Circle()
                    .fill(connection.state == .connected ? Color.green : Color.secondary)
                    .frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            contentSection

            Divider()

            remoteAccessSection

            Divider()

            Button(action: {
                NSApp.setActivationPolicy(.regular)
                (NSApp.delegate as? AppDelegate)?.showMainWindow()
            }) {
                Text("Open Flow")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit Flow")
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .frame(width: 220)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            if FlowShouldAutoSearch {
                connection.startAutoConnect()
            }
        }
    }

    private var statusText: String {
        switch connection.state {
        case .connected: return "Connected"
        case .searching: return "Searching"
        case .connecting: return "Connecting"
        case .disconnected: return "Ready"
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch connection.state {
        case .disconnected:
            Button(action: {
                FlowShouldAutoSearch = true
                connection.startSearching()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 12))
                    Text("Search for iPhone")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

        case .searching:
            if connection.discoveredPeers.isEmpty {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Searching...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            } else {
                ForEach(connection.discoveredPeers) { peer in
                    Button(action: { connection.connect(to: peer) }) {
                        HStack {
                            Text(peer.deviceName)
                                .font(.system(size: 12))
                            Spacer()
                            Text("Connect")
                                .font(.system(size: 11))
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
                }
            }
            Button(action: {
                FlowShouldAutoSearch = false
                connection.cancelSearching()
            }) {
                Text("Cancel")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

        case .connecting:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Connecting...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

        case .connected:
            VStack(alignment: .leading, spacing: 4) {
                Text(connection.connectedPeer?.deviceName ?? "")
                    .font(.system(size: 13, weight: .semibold))
                Text(connection.connectedPeer?.deviceModel ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                if let battery = connection.connectedPeer?.batteryLevel, battery >= 0 {
                    Text("Battery: \(Int(battery))%")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Button(action: { connection.disconnect() }) {
                    Text("Disconnect")
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private var remoteAccessSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Remote Access")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            if let code = pairing.pairingCode {
                Text(code)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .tracking(3)
                Text("Expires in \(pairing.remainingSeconds)s")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Button(action: { pairing.generateCode() }) {
                    HStack(spacing: 6) {
                        if pairing.isBusy {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "qrcode")
                                .font(.system(size: 11))
                        }
                        Text(pairing.isBusy ? "Generating…" : "Generate Pairing Code")
                            .font(.system(size: 12))
                    }
                }
                .buttonStyle(.plain)
                .disabled(pairing.isBusy)
            }

            if let error = pairing.errorMessage {
                Text(error)
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }
}
