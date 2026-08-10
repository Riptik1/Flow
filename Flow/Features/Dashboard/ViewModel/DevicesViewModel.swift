//
//  DevicesViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import Foundation

final class DevicesViewModel: ObservableObject {
    @Published private(set) var devices: [SavedDevice] = []

    private let repository: DeviceRepositoryProtocol
    private var cancellables = Set<AnyCancellable>()

    init(repository: DeviceRepositoryProtocol = DeviceRepository.shared) {
        self.repository = repository
        devices = repository.currentDevices
        repository.devicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.devices = $0 }
            .store(in: &cancellables)
    }

    func reload() {
        repository.reload()
    }

    func connect(_ device: SavedDevice) {
        RemoteConnectionManager.shared.connect(linkID: device.linkID, macID: device.macID)
    }

    func remove(_ device: SavedDevice) {
        repository.remove(device)
        Task {
            await RemoteConnectionManager.shared.forget(linkID: device.linkID)
        }
    }

    func syncConnectedDevice(linkID: UUID?) {
        guard let linkID else { return }
        repository.markConnected(linkID: linkID)
    }
}

struct SavedDevice: Codable, Identifiable, Equatable {
    let linkID: UUID
    let macID: UUID
    let name: String
    let model: String
    var lastConnected: Date

    var id: UUID { linkID }
}

final class SuggestImprovementsViewModel: ObservableObject {
    @Published var feedback: String = ""
    @Published var showSent = false

    var canSend: Bool {
        !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func sendFeedback() {
        showSent = true
    }
}
