import Foundation
import Combine

@MainActor
final class FlowConnectionRepository: NSObject, ObservableObject, FlowConnectionServicing {
    static let shared = FlowConnectionRepository()

    @Published private(set) var state: FlowConnectionState = .disconnected
    @Published private(set) var discoveredPeers: [FlowPeer] = []
    @Published private(set) var connectedPeer: FlowPeer? = nil

    private let localManager = ConnectionManager.shared
    private let remoteManager = RemoteConnectionManager.shared
    private var cancellables = Set<AnyCancellable>()

    private override init() {
        super.init()
        bind()
    }

    private func bind() {
        // localManager.$state
        //     .combineLatest(remoteManager.$state)
        //     .receive(on: DispatchQueue.main)
        //     .sink { [weak self] localState, remoteState in
        //         self?.state = localState != .disconnected ? localState : remoteState
        //     }
        //     .store(in: &cancellables)

        remoteManager.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] remoteState in
                self?.state = remoteState
            }
            .store(in: &cancellables)

        // localManager.$discoveredPeers
        //     .combineLatest(remoteManager.$discoveredPeers)
        //     .receive(on: DispatchQueue.main)
        //     .sink { [weak self] localPeers, remotePeers in
        //         self?.discoveredPeers = localPeers.map(FlowPeer.init(local:)) + remotePeers
        //     }
        //     .store(in: &cancellables)

        remoteManager.$discoveredPeers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peers in
                self?.discoveredPeers = peers
            }
            .store(in: &cancellables)

        // localManager.$connectedPeer
        //     .combineLatest(remoteManager.$connectedPeer)
        //     .receive(on: DispatchQueue.main)
        //     .sink { [weak self] localPeer, remotePeer in
        //         self?.connectedPeer = localPeer.map(FlowPeer.init(local:)) ?? remotePeer
        //     }
        //     .store(in: &cancellables)

        remoteManager.$connectedPeer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peer in
                self?.connectedPeer = peer
            }
            .store(in: &cancellables)
    }

    var messageStream: AnyPublisher<FlowMessage, Never> {
        // localManager.messageStream
        //     .merge(with: remoteManager.messageStream)
        //     .eraseToAnyPublisher()
        remoteManager.messageStream
    }

    func startAutoConnect() {
        // localManager.startAutoConnect()
        remoteManager.startAutoConnect()
    }

    func handleAppForeground() {
        // localManager.handleAppForeground()
        remoteManager.handleAppForeground()
    }

    func startSearching() {
        // localManager.startSearching()
        remoteManager.startSearching()
    }

    func cancelSearching() {
        // localManager.cancelSearching()
        remoteManager.cancelSearching()
    }

    func connect(to peer: FlowPeer) {
        switch peer.transport {
        case .local:
            break
            // if let localPeer = localManager.discoveredPeers.first(where: { FlowPeer(local: $0).id == peer.id }) {
            //     localManager.connect(to: localPeer)
            // }
        case .remote:
            remoteManager.connect(to: peer)
        }
    }

    func disconnect() {
        // localManager.disconnect()
        remoteManager.disconnect()
    }

    func send(_ message: FlowMessage) {
        // if connectedPeer?.transport == .local {
        //     localManager.send(message)
        //     return
        // }
        remoteManager.send(message)
    }

    func sendUnreliable(_ message: FlowMessage) {
        // if connectedPeer?.transport == .local {
        //     localManager.sendUnreliable(message)
        //     return
        // }
        remoteManager.sendUnreliable(message)
    }
}