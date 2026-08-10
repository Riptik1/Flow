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
    @Environment(\.scenePhase) private var scenePhase

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makeDevicesViewModel())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if vm.devices.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(vm.devices) { device in
                            deviceRow(device)
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
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { vm.reload() }
        }
        .onChange(of: connection.state) { _, _ in
            syncConnectedDevice()
        }
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
            Text("Connect to your Mac to see it here")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func deviceRow(_ device: SavedDevice) -> some View {
        let isThisDeviceConnected = connection.connectedLinkID == device.linkID

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
                    Text(device.name)
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

            Button(role: .destructive) {
                vm.remove(device)
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
