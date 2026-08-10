//
//  FlowMacView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 24/05/26.
//

import SwiftUI
import AppKit
import ApplicationServices
import IOKit.hid
import ServiceManagement

struct FlowMacView: View {
    @StateObject private var connection = FlowConnectionRepository.shared
    @StateObject private var pairing = RemotePairingViewModel.shared
    @State private var hoveredRow: UUID? = nil
    @State private var permissions: [MacPermission] = Self.buildPermissions()
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            VisualEffectBackground().ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    deviceCard
                    remoteAccessCard
                    permissionsList
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 32)
            }
        }
        .frame(minWidth: 620, minHeight: 540)
        .onAppear {
            if FlowShouldAutoSearch {
                connection.startAutoConnect()
            }
            refreshPermissions()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissions()
        }
    }

    private var deviceCard: some View {
        ZStack {
            connectedContent
                .blur(radius: connection.state == .connected ? 0 : 10)
                .allowsHitTesting(connection.state == .connected)
                .animation(.easeInOut(duration: 0.3), value: connection.state == .connected)
            if connection.state != .connected {
                deviceOverlay
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var connectedContent: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: .green.opacity(0.7), radius: 3)
                    Text("Connected")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(connection.connectedPeer?.deviceName ?? "")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.primary)
                    Text("\(connection.connectedPeer?.deviceModel ?? "") · \(connectionKindLabel)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 10) {
                    if let battery = connection.connectedPeer?.batteryLevel, battery >= 0 {
                        MiniPill(icon: batteryIcon(for: battery), text: "\(Int(battery))%")
                    }
                    MiniPill(icon: connection.connectedPeer?.transport == .remote ? "globe" : "wifi", text: connectionKindLabel)
                    Button(action: { connection.disconnect() }) {
                        Text("Disconnect")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
            Image(systemName: "iphone")
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.primary.opacity(0.65), .primary.opacity(0.2)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }

    private var connectionKindLabel: String {
        connection.connectedPeer?.transport == .remote ? "Remote" : "Same Wi‑Fi"
    }

    @ViewBuilder
    private var deviceOverlay: some View {
        switch connection.state {
        case .disconnected:
            VStack(spacing: 12) {
                Image(systemName: "iphone.slash")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.secondary)
                Button(action: {
                    FlowShouldAutoSearch = true
                    connection.startSearching()
                }) {
                    HStack(spacing: 7) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Search for iPhone")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.blue))
                }
                .buttonStyle(.plain)
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 28)

        case .searching:
            VStack(spacing: 14) {
                if connection.discoveredPeers.isEmpty {
                    HStack(spacing: 10) {
                        ProgressView().controlSize(.small)
                        Text("Searching for iPhone…")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Found nearby")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        ForEach(connection.discoveredPeers) { peer in
                            PeerRow(peer: peer) { connection.connect(to: peer) }
                        }
                    }
                }
                Button(action: {
                    FlowShouldAutoSearch = false
                    connection.cancelSearching()
                }) {
                    Text("Cancel")
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 22)

        case .connecting:
            VStack(spacing: 10) {
                ProgressView().controlSize(.regular)
                Text("Connecting…")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.vertical, 28)

        case .connected:
            EmptyView()
        }
    }

    private var remoteAccessCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                Text("Remote Access")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }

            if let code = pairing.pairingCode {
                VStack(spacing: 10) {
                    Text(code)
                        .font(.system(size: 30, weight: .bold, design: .monospaced))
                        .tracking(6)
                        .foregroundStyle(.primary)
                    Text("Expires in \(pairing.remainingSeconds)s · Enter this on your iPhone")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button(action: { pairing.generateCode() }) {
                        Text("New Code")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            } else {
                Button(action: { pairing.generateCode() }) {
                    HStack(spacing: 7) {
                        if pairing.isBusy {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "qrcode")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        Text(pairing.isBusy ? "Generating…" : "Generate Pairing Code")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Capsule().fill(Color.blue))
                }
                .buttonStyle(.plain)
                .disabled(pairing.isBusy)
            }

            if let error = pairing.errorMessage {
                Text(error)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }

            Button(action: { pairing.reset() }) {
                Text("Reset this device's pairing")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var permissionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(permissions.enumerated()), id: \.element.id) { index, permission in
                PermissionToggleRow(
                    permission: permission,
                    isHovered: hoveredRow == permission.id,
                    isLast: index == permissions.count - 1,
                    onToggle: { handleToggle(for: index) }
                )
                .onHover { hoveredRow = $0 ? permission.id : nil }
            }
        }
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(
                scheme == .dark
                    ? Color(red: 0.12, green: 0.12, blue: 0.15).opacity(0.9)
                    : Color.white.opacity(0.7)
            )
            .shadow(color: .black.opacity(scheme == .dark ? 0.4 : 0.08), radius: 16, x: 0, y: 8)
    }

    private func handleToggle(for index: Int) {
        if permissions[index].isGranted {
            NSWorkspace.shared.open(URL(string: permissions[index].settingsURL)!)
        } else {
            performRequest(for: index)
        }
    }

    private func performRequest(for index: Int) {
        switch permissions[index].title {

        case "Accessibility":
            let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                permissions[index].isGranted = AXIsProcessTrusted()
            }

        case "Input Monitoring":
            let status = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
            if status == kIOHIDAccessTypeUnknown {
                IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    permissions[index].isGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
                }
            } else {
                NSWorkspace.shared.open(URL(string: permissions[index].settingsURL)!)
            }

        case "Auto Connect":
            do {
                try SMAppService.mainApp.register()
            } catch {
                NSWorkspace.shared.open(URL(string: permissions[index].settingsURL)!)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                permissions[index].isGranted = SMAppService.mainApp.status == .enabled
            }

        case "Full Disk Access":
            let alert = NSAlert()
            alert.messageText = "Add Flow to Full Disk Access"
            alert.informativeText = "System Settings will open.\n\n1. Click the + button at the bottom\n2. Find Flow in your Applications folder\n3. Click Open to add it\n4. Enable the toggle next to Flow"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: permissions[index].settingsURL)!)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                permissions[index].isGranted = permissions[index].checkGranted()
            }

        case "Automation":
            DispatchQueue.global(qos: .userInitiated).async {
                let script = NSAppleScript(source: "tell application \"Finder\" to return name of startup disk")
                var err: NSDictionary?
                script?.executeAndReturnError(&err)
                DispatchQueue.main.async {
                    if err == nil {
                        permissions[index].isGranted = true
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "Add Flow to Automation"
                        alert.informativeText = "System Settings will open.\n\nFlow needs to control Finder and Terminal.\nEnable Flow in the Automation list and turn on the apps listed under it."
                        alert.alertStyle = .informational
                        alert.addButton(withTitle: "Open System Settings")
                        alert.addButton(withTitle: "Cancel")
                        if alert.runModal() == .alertFirstButtonReturn {
                            NSWorkspace.shared.open(URL(string: permissions[index].settingsURL)!)
                        }
                    }
                }
            }

        default:
            NSWorkspace.shared.open(URL(string: permissions[index].settingsURL)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                permissions[index].isGranted = permissions[index].checkGranted()
            }
        }
    }

    private func refreshPermissions() {
        for i in permissions.indices {
            switch permissions[i].title {
            case "Automation":
                guard !permissions[i].isGranted else { continue }
                DispatchQueue.global(qos: .background).async {
                    let script = NSAppleScript(source: "tell application \"Finder\" to return name of startup disk")
                    var err: NSDictionary?
                    script?.executeAndReturnError(&err)
                    let granted = err == nil
                    DispatchQueue.main.async {
                        if granted { permissions[i].isGranted = true }
                    }
                }
            case "Auto Connect":
                permissions[i].isGranted = SMAppService.mainApp.status == .enabled
            default:
                permissions[i].isGranted = permissions[i].checkGranted()
            }
        }
    }

    private func batteryIcon(for level: Float) -> String {
        switch level {
        case ..<10: return "battery.0"
        case ..<25: return "battery.25"
        case ..<50: return "battery.50"
        case ..<75: return "battery.75"
        default:    return "battery.100"
        }
    }

    static func buildPermissions() -> [MacPermission] {
        [
            MacPermission(
                title: "Accessibility",
                detail: "Required to simulate mouse clicks, keyboard input and window management sent from your iPhone.",
                icon: "figure.wave",
                enables: ["Mouse Control", "Click Events", "Window Management"],
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
                isGranted: AXIsProcessTrusted(),
                checkGranted: { AXIsProcessTrusted() },
                requestAccess: {
                    let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
                    AXIsProcessTrustedWithOptions(opts)
                }
            ),
            MacPermission(
                title: "Input Monitoring",
                detail: "Listens to global keyboard and trackpad events streamed from your iPhone.",
                icon: "keyboard",
                enables: ["Keyboard Input", "Trackpad Gestures"],
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent",
                isGranted: IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted,
                checkGranted: { IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted },
                requestAccess: { IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) }
            ),
            MacPermission(
                title: "Auto Connect",
                detail: "Automatically connect with your device on launch without manual searching or pairing every time.",
                icon: "bolt.fill",
                enables: ["Auto Launch", "Background Connect"],
                settingsURL: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension",
                isGranted: SMAppService.mainApp.status == .enabled,
                checkGranted: { SMAppService.mainApp.status == .enabled },
                requestAccess: {
                    do {
                        try SMAppService.mainApp.register()
                    } catch {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!)
                    }
                }
            ),
//            MacPermission(
//                title: "Full Disk Access",
//                detail: "Browse and open any file including Documents, Downloads and developer folders. Tap to add Flow manually via the + button.",
//                icon: "externaldrive",
//                enables: ["All Files", "Documents", "Downloads", "Developer Files"],
//                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles",
//                isGranted: FileManager.default.isReadableFile(atPath: NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"),
//                checkGranted: { FileManager.default.isReadableFile(atPath: NSHomeDirectory() + "/Library/Safari/Bookmarks.plist") },
//                requestAccess: { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!) }
//            ),
//            MacPermission(
//                title: "Automation",
//                detail: "Controls Finder, Terminal and Spotlight. Toggle to trigger the permission prompt, then allow Flow in the dialog.",
//                icon: "terminal",
//                enables: ["Terminal", "Search", "Finder", "Developer Tools"],
//                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation",
//                isGranted: false,
//                checkGranted: { false },
//                requestAccess: {
//                    DispatchQueue.global(qos: .userInitiated).async {
//                        let script = NSAppleScript(source: "tell application \"Finder\" to return name of startup disk")
//                        var err: NSDictionary?
//                        script?.executeAndReturnError(&err)
//                        if err != nil {
//                            DispatchQueue.main.async {
//                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
//                            }
//                        }
//                    }
//                }
//            )
        ]
    }
}

private struct PeerRow: View {
    let peer: FlowPeer
    let onConnect: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone")
                .font(.system(size: 20, weight: .light))
                .foregroundStyle(.primary.opacity(0.7))
                .frame(width: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(peer.deviceName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(peer.deviceModel)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onConnect) {
                Text("Connect")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue))
            }
            .buttonStyle(.plain)
            .shadow(color: .blue.opacity(0.3), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(isHovered ? 0.07 : 0.04))
        )
        .onHover { isHovered = $0 }
    }
}

private struct PermissionToggleRow: View {
    let permission: MacPermission
    let isHovered: Bool
    let isLast: Bool
    let onToggle: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 32, height: 32)
                    Image(systemName: permission.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                .padding(.top, 1)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(permission.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        if permission.isGranted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(.green)
                        }
                    }
                    Text(permission.detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 5) {
                        ForEach(permission.enables.prefix(5), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(Color.primary.opacity(0.07)))
                        }
                    }
                    .padding(.top, 2)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { permission.isGranted },
                    set: { _ in onToggle() }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isHovered ? Color.primary.opacity(scheme == .dark ? 0.04 : 0.025) : .clear)
            .animation(.easeInOut(duration: 0.12), value: isHovered)

            if !isLast {
                Divider().padding(.leading, 62).padding(.trailing, 16)
            }
        }
    }
}

private struct MiniPill: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(Color.primary.opacity(0.07)))
    }
}

struct MacPermission: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let icon: String
    let enables: [String]
    let settingsURL: String
    var isGranted: Bool
    let checkGranted: () -> Bool
    let requestAccess: () -> Void
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.material = .sidebar
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

#Preview {
    FlowMacView().frame(width: 660, height: 620)
}
