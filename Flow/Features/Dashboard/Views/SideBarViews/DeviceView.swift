//
//  SavedDevice.swift
//  Flow
//
//  Created by Riptik Jhajhria on 09/06/26.
//

import SwiftUI
import Combine

struct SavedDevice: Codable, Identifiable, Equatable {
    var id: String { name }
    let name: String
    let lastConnected: Date
}

class DevicesStore: ObservableObject {
    @Published var devices: [SavedDevice] = []

    private let storageKey = "flow.savedDevices"

    init() {
        load()
    }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([SavedDevice].self, from: data) else {
            devices = []
            return
        }
        devices = decoded.sorted { $0.lastConnected > $1.lastConnected }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func markConnected(name: String) {
        let device = SavedDevice(name: name, lastConnected: Date())
        devices.removeAll { $0.name == name }
        devices.insert(device, at: 0)
        devices.sort { $0.lastConnected > $1.lastConnected }
        save()
    }

    func remove(device: SavedDevice) {
        devices.removeAll { $0.id == device.id }
        save()
    }
}

struct DevicesView: View {
    @StateObject private var store = DevicesStore()
    @ObservedObject private var connection = ConnectionManager.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                HStack {
                    Text("Devices")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                if store.devices.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 12) {
                        ForEach(store.devices) { device in
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
            store.load()
            syncConnectedDevice()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                store.load()
            }
        }
        .onChange(of: connection.state) { _, _ in
            syncConnectedDevice()
        }
    }

    private func syncConnectedDevice() {
        guard connection.state == .connected, let peer = connection.connectedPeer else { return }
        store.markConnected(name: peer.deviceName)
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
        let isThisDeviceConnected = connection.state == .connected && connection.connectedPeer?.deviceName == device.name

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

                if !isThisDeviceConnected {
                    Button {
                        store.remove(device: device)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.red.opacity(0.8))
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.red.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
