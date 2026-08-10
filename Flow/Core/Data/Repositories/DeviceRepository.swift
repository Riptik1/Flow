import Combine
import Foundation

final class DeviceRepository: DeviceRepositoryProtocol, ObservableObject {
    static let shared = DeviceRepository()

    @Published private(set) var devices: [SavedDevice] = []

    var currentDevices: [SavedDevice] { devices }
    var devicesPublisher: AnyPublisher<[SavedDevice], Never> { $devices.eraseToAnyPublisher() }

    private let store = UserDefaultsCodableStore<[SavedDevice]>(key: "flow.savedDevices")

    init() { reload() }

    func reload() {
        guard let decoded = store.load() else {
            devices = []
            return
        }
        devices = decoded.sorted { $0.lastConnected > $1.lastConnected }
    }

    func markConnected(name: String) {
        let device = SavedDevice(name: name, lastConnected: Date())
        devices.removeAll { $0.name == name }
        devices.insert(device, at: 0)
        devices.sort { $0.lastConnected > $1.lastConnected }
        store.save(devices)
    }

    func remove(_ device: SavedDevice) {
        devices.removeAll { $0.id == device.id }
        store.save(devices)
    }
}
