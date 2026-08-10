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

    func remove(_ device: SavedDevice) {
        repository.remove(device)
    }

    func syncConnectedDevice(isConnected: Bool, peerName: String?) {
        guard isConnected, let peerName else { return }
        repository.markConnected(name: peerName)
    }
}
