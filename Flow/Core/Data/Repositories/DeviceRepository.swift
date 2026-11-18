//
//  DeviceRepository.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import Foundation

protocol DeviceRepositoryProtocol: AnyObject {
    var currentDevices: [SavedDevice] { get }
    var devicesPublisher: AnyPublisher<[SavedDevice], Never> { get }

    func reload()
    func markConnected(linkID: UUID)
    func remove(_ device: SavedDevice)
}

final class DeviceRepository: DeviceRepositoryProtocol, ObservableObject {
    static let shared = DeviceRepository()

    @Published private(set) var devices: [SavedDevice] = []

    var currentDevices: [SavedDevice] { devices }
    var devicesPublisher: AnyPublisher<[SavedDevice], Never> { $devices.eraseToAnyPublisher() }

    private let store = UserDefaultsCodableStore<[SavedDevice]>(key: "flow.savedDevices")
    private var reloadTask: Task<Void, Never>?

    init() {
        if let cached = store.load() {
            devices = cached.sorted { $0.lastConnected > $1.lastConnected }
        }
        reload()
    }

    func reload() {
        reloadTask?.cancel()
        reloadTask = Task { [weak self] in
            await self?.performReload()
        }
    }

    func markConnected(linkID: UUID) {
        guard let index = devices.firstIndex(where: { $0.linkID == linkID }) else { return }
        devices[index].lastConnected = Date()
        devices.sort { $0.lastConnected > $1.lastConnected }
        store.save(devices)
    }

    func remove(_ device: SavedDevice) {
        devices.removeAll { $0.id == device.id }
        store.save(devices)
    }

    private func performReload() async {
        flowLog("[Flow][DeviceRepo] performReload: start")
        guard let iphoneID = try? await SupabaseManager.shared.ensureSession() else {
            flowLog("[Flow][DeviceRepo] performReload: ensureSession FAILED")
            return
        }
        guard let links = try? await FlowBackendClient.shared.fetchTrustedLinks(iphoneID: iphoneID) else {
            flowLog("[Flow][DeviceRepo] performReload: fetchTrustedLinks FAILED")
            return
        }
        guard !Task.isCancelled else { return }

        let cachedByLink = Dictionary(uniqueKeysWithValues: devices.map { ($0.linkID, $0) })
        var resolved: [SavedDevice] = []
        // Re-pairing the same Mac creates a new link; only list each Mac once (newest link).
        var newestPerMac: [UUID: DeviceLinkRow] = [:]
        for link in links {
            if let existing = newestPerMac[link.macID], existing.createdAt >= link.createdAt { continue }
            newestPerMac[link.macID] = link
        }
        for link in newestPerMac.values {
            guard !Task.isCancelled else { return }
            let info = try? await FlowBackendClient.shared.fetchMacInfo(id: link.macID)
            let cached = cachedByLink[link.id]
            resolved.append(
                SavedDevice(
                    linkID: link.id,
                    macID: link.macID,
                    name: info?.deviceName ?? cached?.name ?? "Mac",
                    model: info?.deviceModel ?? cached?.model ?? "Mac",
                    lastConnected: cached?.lastConnected ?? link.createdAt
                )
            )
        }
        guard !Task.isCancelled else { return }

        let sorted = resolved.sorted { $0.lastConnected > $1.lastConnected }
        flowLog("[Flow][DeviceRepo] performReload: resolved \(sorted.count) device(s)")
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.devices = sorted
            self.store.save(sorted)
        }
    }
}
