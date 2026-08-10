import Combine
import Foundation

final class RecentFilesRepository: RecentFilesRepositoryProtocol, ObservableObject {
    static let shared = RecentFilesRepository(connectionService: LiveFlowConnectionService.shared)

    @Published private(set) var files: [RemoteFileItem] = []

    var currentFiles: [RemoteFileItem] { files }
    var filesPublisher: AnyPublisher<[RemoteFileItem], Never> { $files.eraseToAnyPublisher() }

    private let store = UserDefaultsCodableStore<[RemoteFileItem]>(key: "flow_cached_files_v3")
    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()

    init(connectionService: FlowConnectionServicing) {
        self.connectionService = connectionService
        if let cached = store.load() { files = cached }
        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handle($0) }
            .store(in: &cancellables)
    }

    func refresh(limit: Int) {
        guard connectionService.isConnected else { return }
        connectionService.send(.requestRecentFiles(limit: limit))
    }

    private func handle(_ message: FlowMessage) {
        guard case .recentFiles(let received) = message else { return }
        files = received
        store.save(received)
    }
}
