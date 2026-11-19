//
//  DeviceView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 09/06/26.
//

import SwiftUI

struct DevicesView: View {
    let factory: FlowViewModelFactory
    @StateObject private var vm: DevicesViewModel
    @StateObject private var connection = RemoteConnectionManager.shared
    @ObservedObject private var repo = FlowConnectionRepository.shared
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var aliases = DeviceAliasStore.shared
    @State private var showRemotePairing = false
    /// Real device name of the Mac being renamed, and the text being typed.
    @State private var renameTarget: String?
    @State private var renameText = ""
    @State private var deleteTarget: SavedDevice?

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makeDevicesViewModel())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if vm.devices.isEmpty && localPeers.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(vm.devices) { device in
                            deviceRow(device)
                        }
                        ForEach(localPeers) { peer in
                            localPeerRow(peer)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer(minLength: 40)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Devices")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.reload()
            syncConnectedDevice()
            if repo.state == .disconnected { repo.startSearching() }
        }
        .sheet(isPresented: $showRemotePairing) { RemotePairingView() }
        .alert("Rename Device", isPresented: Binding(
            get: { renameTarget != nil },
            set: { if !$0 { renameTarget = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Save") {
                if let target = renameTarget { aliases.setName(renameText, for: target) }
                renameTarget = nil
            }
            Button("Cancel", role: .cancel) { renameTarget = nil }
        } message: {
            Text("Choose how this device is named in Flow.")
        }
        .confirmationDialog(
            "Delete this device?",
            isPresented: Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let device = deleteTarget {
                    vm.remove(device)
                    aliases.removeName(for: device.name)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("You'll need to pair it again to use it remotely.")
        }
        .onChange(of: repo.connectedPeer?.deviceName) { _, name in
            if let name { aliases.unhide(name) }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { vm.reload() }
        }
        .onChange(of: connection.state) { _, _ in
            syncConnectedDevice()
        }
    }

    /// Macs reachable over Wi-Fi (connected or nearby) that are not already listed as a paired device.
    private var localPeers: [DiscoveredPeer] {
        var peers = repo.discoveredPeers.filter { $0.platform == "Mac" }
        if let current = repo.connectedPeer, current.transport == .local,
           !peers.contains(where: { $0.deviceName == current.deviceName }) {
            peers.insert(current, at: 0)
        }
        let pairedNames = Set(vm.devices.map(\.name))
        let connectedName = repo.connectedPeer?.deviceName
        return peers.filter {
            !pairedNames.contains($0.deviceName)
                && (!aliases.hidden.contains($0.deviceName) || $0.deviceName == connectedName)
        }
    }

    private func localPeerRow(_ peer: DiscoveredPeer) -> some View {
        let isConnected = repo.state == .connected && repo.connectedPeer?.deviceName == peer.deviceName
        return GlassCard(cornerRadius: 16, padding: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                    Image("macbook")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(aliases.displayName(for: peer.deviceName))
                        .font(.system(size: 16, weight: .semibold))
                    if isConnected {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .shadow(color: .green.opacity(0.7), radius: 3)
                            Text("Connected · Same Wi‑Fi")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Nearby · Same Wi‑Fi")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Label("Tap to enable remote access", systemImage: "personalhotspot")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                }

                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { showRemotePairing = true }
        .contextMenu {
            Button {
                repo.connect(to: peer)
            } label: {
                Label("Connect", systemImage: "personalhotspot")
            }
            .disabled(isConnected)

            Button {
                beginRename(deviceName: peer.deviceName)
            } label: {
                Label("Edit Name", systemImage: "pencil")
            }

            Button(role: .destructive) {
                forgetLocal(peer, isConnected: isConnected)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func beginRename(deviceName: String) {
        renameText = aliases.displayName(for: deviceName)
        renameTarget = deviceName
    }

    /// A nearby Mac can't be un-paired, so deleting it stops auto-connect, disconnects it and hides it.
    private func forgetLocal(_ peer: DiscoveredPeer, isConnected: Bool) {
        if ConnectionManager.shared.savedPeerName == peer.deviceName {
            ConnectionManager.shared.savedPeerName = nil
        }
        if isConnected { repo.disconnect() }
        aliases.removeName(for: peer.deviceName)
        aliases.hide(peer.deviceName)
    }

    private func syncConnectedDevice() {
        vm.syncConnectedDevice(linkID: connection.connectedLinkID)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                Image(systemName: "laptopcomputer.and.iphone")
                    .font(.system(size: 32))
                    .foregroundStyle(.blue)
            }
            Text("No Devices")
                .font(.system(size: 18, weight: .semibold))
            Text("Connect to your Mac to see it here. Devices on your Wi-Fi and Macs paired for remote access are listed.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func deviceRow(_ device: SavedDevice) -> some View {
        let isThisDeviceConnected = connection.connectedLinkID == device.linkID
            || (repo.state == .connected && repo.connectedPeer?.deviceName == device.name)

        return GlassCard(cornerRadius: 16, padding: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(0.12))
                    Image("macbook")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                }
                .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 3) {
                    Text(aliases.displayName(for: device.name))
                        .font(.system(size: 16, weight: .semibold))

                    if isThisDeviceConnected {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                                .shadow(color: .green.opacity(0.7), radius: 3)
                            Text("Connected")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("Last connected \(formattedDate(device.lastConnected))")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    Label("Can be connected remotely", systemImage: "globe")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.green)
                }

                Spacer()
            }
        }
        .contextMenu {
            Button {
                vm.connect(device)
            } label: {
                Label("Connect", systemImage: "personalhotspot")
            }
            .disabled(isThisDeviceConnected)

            Button {
                beginRename(deviceName: device.name)
            } label: {
                Label("Edit Name", systemImage: "pencil")
            }

            Button(role: .destructive) {
                deleteTarget = device
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
