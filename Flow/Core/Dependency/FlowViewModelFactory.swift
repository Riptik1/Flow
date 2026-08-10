import Foundation

protocol FlowViewModelFactory {
    func makeFileStore() -> FileStore
    func makeFileListViewModel() -> FileListViewModel
    func makeKeyboardViewModel() -> KeyboardViewModel
    func makeTrackpadViewModel() -> TrackpadViewModel
}

final class DefaultFlowViewModelFactory: FlowViewModelFactory {
    static let shared = DefaultFlowViewModelFactory()

    private let connectionService: FlowConnectionServicing

    init(connectionService: FlowConnectionServicing = LiveFlowConnectionService.shared) {
        self.connectionService = connectionService
    }

    func makeFileStore() -> FileStore {
        FileStore(connectionService: connectionService)
    }

    func makeFileListViewModel() -> FileListViewModel {
        FileListViewModel(connectionService: connectionService)
    }

    func makeKeyboardViewModel() -> KeyboardViewModel {
        KeyboardViewModel(connectionService: connectionService)
    }

    func makeTrackpadViewModel() -> TrackpadViewModel {
        TrackpadViewModel()
    }
}
