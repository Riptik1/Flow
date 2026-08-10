import SwiftUI
import AppKit
import ApplicationServices
import IOKit.hid
import ServiceManagement

struct FlowMenuBarView: View {
    @StateObject private var connection = ConnectionManager.shared
    @State private var permissions: [MacPermission] = FlowMacView.buildPermissions()

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

            VStack(alignment: .leading, spacing: 0) {
                Text("Permissions")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)

                ForEach(permissions) { permission in
                    HStack {
                        Image(systemName: permission.icon)
                            .frame(width: 20)
                            .foregroundStyle(.secondary)
                        Text(permission.title)
                            .font(.system(size: 12))
                        Spacer()
                        if permission.isGranted {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.green)
                                .font(.system(size: 11))
                        } else {
                            Button("Grant") {
                                handlePermission(permission)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(.blue)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                }
            }

            Divider()

            Button(action: {
                NSApp.setActivationPolicy(.regular)
                (NSApp.delegate as? AppDelegate)?.showMainWindow()
            }) {
                Text("Open Flow")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Text("Quit Flow")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
        .frame(width: 260)
        .onAppear {
            if FlowShouldAutoSearch {
                connection.startAutoConnect()
            }
            refreshPermissions()
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
                    Text("Search for iPhone")
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
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

        case .connecting:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Connecting...")
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
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
        }
    }

    private func handlePermission(_ permission: MacPermission) {
        switch permission.title {
        case "Accessibility":
            let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(opts)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let index = self.permissions.firstIndex(where: { $0.id == permission.id }) {
                    self.permissions[index].isGranted = AXIsProcessTrusted()
                }
            }
        case "Input Monitoring":
            let status = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
            if status == kIOHIDAccessTypeUnknown {
                IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if let index = self.permissions.firstIndex(where: { $0.id == permission.id }) {
                        self.permissions[index].isGranted = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
                    }
                }
            } else {
                NSWorkspace.shared.open(URL(string: permission.settingsURL)!)
            }
        case "Full Disk Access":
            let alert = NSAlert()
            alert.messageText = "Add Flow to Full Disk Access"
            alert.informativeText = "System Settings will open. Click +, find Flow, and enable it."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Open Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(URL(string: permission.settingsURL)!)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if let index = self.permissions.firstIndex(where: { $0.id == permission.id }) {
                    self.permissions[index].isGranted = self.permissions[index].checkGranted()
                }
            }
        case "Automation":
            DispatchQueue.global(qos: .userInitiated).async {
                let script = NSAppleScript(source: "tell application \"Finder\" to return name of startup disk")
                var err: NSDictionary?
                script?.executeAndReturnError(&err)
                DispatchQueue.main.async {
                    if err == nil {
                        if let index = self.permissions.firstIndex(where: { $0.id == permission.id }) {
                            self.permissions[index].isGranted = true
                        }
                    } else {
                        NSWorkspace.shared.open(URL(string: permission.settingsURL)!)
                    }
                }
            }
        case "Login Items":
            do {
                try SMAppService.mainApp.register()
            } catch {
                NSWorkspace.shared.open(URL(string: permission.settingsURL)!)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let index = self.permissions.firstIndex(where: { $0.id == permission.id }) {
                    self.permissions[index].isGranted = SMAppService.mainApp.status == .enabled
                }
            }
        default:
            NSWorkspace.shared.open(URL(string: permission.settingsURL)!)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if let index = self.permissions.firstIndex(where: { $0.id == permission.id }) {
                    self.permissions[index].isGranted = self.permissions[index].checkGranted()
                }
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
                        if granted { self.permissions[i].isGranted = true }
                    }
                }
            case "Login Items":
                permissions[i].isGranted = SMAppService.mainApp.status == .enabled
            default:
                permissions[i].isGranted = permissions[i].checkGranted()
            }
        }
    }
}