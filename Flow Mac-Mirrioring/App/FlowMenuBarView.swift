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
    // @StateObject private var connection = ConnectionManager.shared
    @StateObject private var connection = RemoteConnectionManager.shared

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
            // if FlowShouldAutoSearch {
            //     ConnectionManager.shared.startAutoConnect()
            // }
            connection.startAutoConnect()
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
                // FlowShouldAutoSearch = true
                // ConnectionManager.shared.startSearching()
                connection.beginPairingAsOwner()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 12))
                    Text("Generate Pairing Code")
                        .font(.system(size: 12))
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

        case .searching:
            if let code = connection.pairingCode {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enter this code on your iPhone")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text(code)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .tracking(3)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Generating code...")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
            }
            Button(action: {
                // FlowShouldAutoSearch = false
                // ConnectionManager.shared.cancelSearching()
                connection.cancelPairing()
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
                Text(connection.pairedPeer?.peerName ?? "")
                    .font(.system(size: 13, weight: .semibold))
                Text("Paired remotely")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button(action: { connection.revokeCurrentPair() }) {
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
}
