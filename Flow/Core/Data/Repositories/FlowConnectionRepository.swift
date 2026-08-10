//
//  FlowConnectionRepository.swift
//  Flow
//
//  Created by Riptik Jhajhria on 13/07/26.
//

import Combine
import Foundation
import Network

#if canImport(AppKit)
import AppKit
#endif

final class FlowConnectionRepository: ObservableObject, FlowConnectionServicing {
    static let shared = FlowConnectionRepository()

    @Published var state: FlowConnectionState = .disconnected {
        didSet {
            print("[Flow][Repo] state changed: \(oldValue) -> \(state)")
        }
    }
    @Published var discoveredPeers: [DiscoveredPeer] = []
    @Published var connectedPeer: DiscoveredPeer? = nil
    @Published var pairingError: String? = nil
    @Published var macProfileImageData: Data? = nil

    private let remote = RemoteConnectionManager.shared
    private let local = ConnectionManager.shared

    @Published private(set) var isOnWiFi = true
    private let pathMonitor = NWPathMonitor()
    private let pathMonitorQueue = DispatchQueue(label: "com.flow.pathMonitor")

    private let messageSubject = PassthroughSubject<FlowMessage, Never>()
    var messageStream: AnyPublisher<FlowMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    var isConnected: Bool { state == .connected }
    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        $state.map { $0 == .connected }.eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()

    private init() {
        print("[Flow][Repo] init")
        bindRemote()
        bindLocal()
        startNetworkMonitoring()
        bindMacUnlockMonitoring()
    }

    private func startNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let onWiFi = path.usesInterfaceType(.wifi)
            DispatchQueue.main.async {
                guard let self else { return }
                if self.isOnWiFi != onWiFi {
                    print("[Flow][Repo] network path changed: onWiFi=\(onWiFi)")
                }
                self.isOnWiFi = onWiFi
            }
        }
        pathMonitor.start(queue: pathMonitorQueue)
    }

    #if canImport(AppKit)
    private func bindMacUnlockMonitoring() {
        $connectedPeer
            .receive(on: DispatchQueue.main)
            .map { $0 != nil }
            .removeDuplicates()
            .sink { [weak self] hasPeer in
                guard let self else { return }
                if hasPeer {
                    print("[Flow][Repo] connectedPeer active, starting Mac lock monitoring")
                    MacUnlockService.shared.startMonitoring { [weak self] message in
                        self?.send(message)
                    }
                } else {
                    print("[Flow][Repo] connectedPeer cleared, stopping Mac lock monitoring")
                    MacUnlockService.shared.stopMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    #else
    private func bindMacUnlockMonitoring() {}
    #endif

    private func bindRemote() {
        remote.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                guard self.connectedPeer?.transport != .local else { return }
                self.state = newState
            }
            .store(in: &cancellables)

        remote.$connectedPeer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peer in
                guard let self else { return }
                print("[Flow][Repo] connectedPeer changed (remote): \(peer?.deviceName ?? "nil")")
                if let peer {
                    guard self.connectedPeer?.transport != .local else { return }
                    self.connectedPeer = peer
                    self.local.cancelSearching()
                } else if self.connectedPeer?.transport == .remote {
                    self.connectedPeer = nil
                    if self.isOnWiFi {
                        self.local.startAutoConnect()
                    }
                }
            }
            .store(in: &cancellables)

        remote.$pairingError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                if let error {
                    print("[Flow][Repo] pairingError set: \(error)")
                }
                self?.pairingError = error
            }
            .store(in: &cancellables)

        remote.messageStream
            .sink { [weak self] message in
                self?.routeIncoming(message)
            }
            .store(in: &cancellables)

        remote.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                if newState == .disconnected, self.connectedPeer?.transport != .local {
                    self.macProfileImageData = nil
                }
            }
            .store(in: &cancellables)
    }

    private func bindLocal() {
        local.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                guard let self else { return }
                guard self.connectedPeer?.transport != .remote else { return }
                self.state = newState
            }
            .store(in: &cancellables)

        local.$discoveredPeers
            .receive(on: DispatchQueue.main)
            .assign(to: \.discoveredPeers, on: self)
            .store(in: &cancellables)

        local.$connectedPeer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] peer in
                guard let self else { return }
                print("[Flow][Repo] connectedPeer changed (local): \(peer?.deviceName ?? "nil")")
                if let peer {
                    guard self.connectedPeer?.transport != .remote else { return }
                    self.connectedPeer = peer
                    self.remote.pauseAutoConnect()
                } else if self.connectedPeer?.transport == .local {
                    self.connectedPeer = nil
                    self.remote.resumeAutoConnect()
                }
            }
            .store(in: &cancellables)

        local.$macProfileImageData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] data in
                guard self?.connectedPeer?.transport != .remote else { return }
                self?.macProfileImageData = data
            }
            .store(in: &cancellables)

        local.messageStream
            .sink { [weak self] message in
                self?.messageSubject.send(message)
            }
            .store(in: &cancellables)
    }

    private func routeIncoming(_ message: FlowMessage) {
        switch message {
        case .macUserProfile(let imageData):
            macProfileImageData = imageData
            messageSubject.send(message)

        default:
            messageSubject.send(message)
        }
    }

    func send(_ message: FlowMessage) {
        if connectedPeer?.transport == .local {
            print("[Flow][Repo] send: routing over local, message=\(message)")
            local.send(message)
        } else {
            print("[Flow][Repo] send: routing over remote, message=\(message)")
            remote.send(message)
        }
    }

    private let localFirstGraceSeconds: TimeInterval = 3.0
    private var remoteKickoffWork: DispatchWorkItem?

    private func triggerRemoteAutoConnect(immediate: Bool) {
        remoteKickoffWork?.cancel()
        guard !immediate else {
            print("[Flow][Repo] triggerRemoteAutoConnect: not on Wi-Fi, starting remote immediately")
            remote.startAutoConnect()
            return
        }
        print("[Flow][Repo] triggerRemoteAutoConnect: on Wi-Fi, giving local a \(localFirstGraceSeconds)s head start before starting remote")
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.connectedPeer?.transport != .local else {
                print("[Flow][Repo] triggerRemoteAutoConnect: local already connected during grace period, skipping remote start")
                return
            }
            self.remote.startAutoConnect()
        }
        remoteKickoffWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + localFirstGraceSeconds, execute: work)
    }

    func startAutoConnect() {
        print("[Flow][Repo] startAutoConnect isOnWiFi=\(isOnWiFi)")
        if isOnWiFi, connectedPeer?.transport != .remote {
            local.startAutoConnect()
            triggerRemoteAutoConnect(immediate: false)
        } else {
            triggerRemoteAutoConnect(immediate: true)
        }
    }

    private func triggerRemoteForeground(immediate: Bool) {
        remoteKickoffWork?.cancel()
        guard !immediate else {
            remote.handleAppForeground()
            return
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard self.connectedPeer?.transport != .local else {
                print("[Flow][Repo] triggerRemoteForeground: local already connected during grace period, skipping remote foreground kick")
                return
            }
            self.remote.handleAppForeground()
        }
        remoteKickoffWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + localFirstGraceSeconds, execute: work)
    }

    func handleAppForeground() {
        print("[Flow][Repo] handleAppForeground isOnWiFi=\(isOnWiFi)")
        if isOnWiFi, connectedPeer?.transport != .remote {
            local.handleAppForeground()
            triggerRemoteForeground(immediate: false)
        } else {
            triggerRemoteForeground(immediate: true)
        }
    }

    func redeem(code: String) {
        print("[Flow][Repo] redeem: code=\(code)")
        remote.redeem(code: code)
    }

    func startSearching() {
        local.startSearching()
    }

    func cancelSearching() {
        local.cancelSearching()
    }

    func connect(to peer: DiscoveredPeer) {
        local.connect(to: peer)
    }

    func disconnect() {
        print("[Flow][Repo] disconnect")
        remote.disconnect()
        local.disconnect()
    }
}
