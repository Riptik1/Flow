//
//  RemoteConnectionManager.swift
//  Flow
//
//  Created by Riptik Jhajhria on 13/07/26.
//

import Combine
import Foundation
import MultipeerConnectivity
import Supabase

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
import Darwin
#endif

@MainActor
final class RemoteConnectionManager: ObservableObject {
    static let shared = RemoteConnectionManager()

    @Published var state: FlowConnectionState = .disconnected {
        didSet {
            print("[Flow][RCM] state changed: \(oldValue) -> \(state)")
        }
    }
    @Published var connectedPeer: DiscoveredPeer? = nil
    @Published var pairingError: String? = nil

    private let backend = FlowBackendClient.shared
    private let messageSubject = PassthroughSubject<FlowMessage, Never>()

    var messageStream: AnyPublisher<FlowMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()
    private var listeningChannels: [UUID: RemoteMessageChannel] = [:]
    private var activeChannel: RemoteMessageChannel?
    private var activeLinkID: UUID?
    private var registeredDeviceID: UUID?

    private var autoConnectTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var handshakeTimeoutTask: Task<Void, Never>?
    private var linkPollTask: Task<Void, Never>?
    private var ackRetryTask: Task<Void, Never>?
    #if canImport(UIKit)
    private var beaconTask: Task<Void, Never>?
    #endif
    private var sendChain: Task<Void, Never>?
    private var socketStatusTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?

    private var isPaused = false

    private var lifecycleObserversRegistered = false
    #if canImport(AppKit)
    private var backgroundActivityToken: NSObjectProtocol?
    #endif
    private var isHardReconnecting = false

    #if canImport(AppKit)
    private var wakeObserver: NSObjectProtocol?
    private var sleepObserver: NSObjectProtocol?
    #endif

    #if canImport(UIKit)
    private var foregroundObserver: NSObjectProtocol?
    #endif

    private init() {}

    func startAutoConnect() {
        guard autoConnectTask == nil else {
            print("[Flow][RCM] startAutoConnect: already running, ignoring")
            return
        }
        print("[Flow][RCM] startAutoConnect: launching")
        maintainBackgroundActivity()
        autoConnectTask = Task { [weak self] in
            await self?.runAutoConnect()
            self?.autoConnectTask = nil
            print("[Flow][RCM] startAutoConnect: runAutoConnect task finished")
        }
    }

    func handleAppForeground() {
        print("[Flow][RCM] handleAppForeground: state=\(state) isPaused=\(isPaused)")
        guard !isPaused else {
            print("[Flow][RCM] handleAppForeground: paused while local transport is active, ignoring")
            return
        }
        switch state {
        case .disconnected:
            startAutoConnect()
        case .connecting:
            print("[Flow][RCM] handleAppForeground: handshake already in progress, leaving it alone")
        case .searching:
            break
        case .connected:
            if let channel = activeChannel, !channel.isHealthy {
                print("[Flow][RCM] handleAppForeground: connected but channel unhealthy, hard reconnecting")
                Task { await hardReconnect() }
            } else {
                print("[Flow][RCM] handleAppForeground: connected and healthy, nothing to do")
            }
        }
    }

    func pauseAutoConnect() {
        guard !isPaused else { return }
        isPaused = true
        print("[Flow][RCM] pauseAutoConnect: local transport is active, backing off")
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil
        ackRetryTask?.cancel()
        ackRetryTask = nil
        #if canImport(UIKit)
        beaconTask?.cancel()
        beaconTask = nil
        #endif
        if let linkID = activeLinkID {
            listeningChannels.removeValue(forKey: linkID)
        }
        if let channel = activeChannel {
            activeChannel = nil
            activeLinkID = nil
            sendChain = nil
            resetFrameSendState()
            Task { await channel.disconnect() }
        }
        if state != .disconnected {
            state = .disconnected
            connectedPeer = nil
        }
    }

    func resumeAutoConnect() {
        guard isPaused else { return }
        isPaused = false
        print("[Flow][RCM] resumeAutoConnect: local transport is no longer active, resuming remote")
        #if canImport(AppKit)
        if let macID = registeredDeviceID {
            Task { await refreshTrustedLinks(macID: macID) }
        }
        #else
        if state == .disconnected, let deviceID = registeredDeviceID {
            Task { await connectToMostRecentTrustedLink(iphoneID: deviceID) }
        }
        #endif
    }

    @discardableResult
    func ensureRegistered() async throws -> UUID {
        print("[Flow][RCM] ensureRegistered: calling backend.ensureRegisteredSession")
        let id = try await backend.ensureRegisteredSession(deviceName: localDeviceName, deviceModel: localDeviceModel)
        print("[Flow][RCM] ensureRegistered: succeeded id=\(id)")
        return id
    }

    func send(_ message: FlowMessage) {
        guard activeChannel != nil else {
            print("[Flow][RCM] send: no activeChannel, dropping message=\(message)")
            return
        }
        print("[Flow][RCM] send: queuing message=\(message) on linkID=\(activeLinkID?.uuidString ?? "nil")")
        let previous = sendChain
        sendChain = Task { [weak self] in
            _ = await previous?.value
            guard let self, let channel = self.activeChannel else {
                print("[Flow][RCM] send: channel gone before message could be sent, dropping message=\(message)")
                return
            }
            var attempt = 0
            while attempt < 3 {
                let ok = await withTaskGroup(of: Bool?.self) { group -> Bool? in
                    group.addTask { Optional(await channel.send(message)) }
                    group.addTask {
                        try? await Task.sleep(nanoseconds: 5_000_000_000)
                        return Bool?.none
                    }
                    let first = await group.next() ?? nil
                    group.cancelAll()
                    return first
                }
                if ok == true { return }
                if ok == nil {
                    print("[Flow][RCM] send: attempt timed out after 5s, message=\(message)")
                }
                attempt += 1
                if attempt < 3 {
                    print("[Flow][RCM] send: attempt \(attempt) failed, retrying message=\(message)")
                    try? await Task.sleep(nanoseconds: 200_000_000)
                }
            }
            print("[Flow][RCM] send: gave up after \(attempt) attempts, dropping message=\(message)")
        }
    }

    private func resetFrameSendState() {
        RemoteFrameTransport.shared.attach(activeChannel)
    }

    func redeem(code: String) {
        print("[Flow][RCM] redeem: code=\(code)")
        #if canImport(UIKit)
        Task { await performRedeem(code: code) }
        #else
        print("[Flow][RCM] redeem: called on non-UIKit platform, ignoring")
        #endif
    }

    func disconnect() {
        print("[Flow][RCM] disconnect: called, tearing down all tasks and channels")
        isPaused = false
        autoConnectTask?.cancel()
        autoConnectTask = nil
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil
        linkPollTask?.cancel()
        linkPollTask = nil
        ackRetryTask?.cancel()
        ackRetryTask = nil
        socketStatusTask?.cancel()
        socketStatusTask = nil
        watchdogTask?.cancel()
        watchdogTask = nil
        #if canImport(UIKit)
        beaconTask?.cancel()
        beaconTask = nil
        #endif
        Task {
            await activeChannel?.disconnect()
            for (id, channel) in listeningChannels {
                print("[Flow][RCM] disconnect: disconnecting listening channel linkID=\(id)")
                await channel.disconnect()
            }
            listeningChannels.removeAll()
            activeChannel = nil
            activeLinkID = nil
            sendChain = nil
            registeredDeviceID = nil
            connectedPeer = nil
            pairingError = nil
            state = .disconnected
            stopHeartbeat()
            resetFrameSendState()
            print("[Flow][RCM] disconnect: complete")
        }
    }

    private func attemptRegistration() async -> UUID? {
        await withTaskGroup(of: UUID?.self) { group in
            group.addTask { [weak self] in
                guard let self else { return nil }
                return try? await self.backend.ensureRegisteredSession(
                    deviceName: self.localDeviceName,
                    deviceModel: self.localDeviceModel
                )
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private func runAutoConnect() async {
        print("[Flow][RCM] runAutoConnect: start")
        var attempt = 0
        var deviceID: UUID? = nil
        while deviceID == nil, !Task.isCancelled {
            attempt += 1
            deviceID = await attemptRegistration()
            if let deviceID {
                print("[Flow][RCM] runAutoConnect: registered deviceID=\(deviceID) on attempt \(attempt)")
            } else {
                let delay = min(Double(attempt) * 2.0, 30.0)
                print("[Flow][RCM] runAutoConnect: attempt \(attempt) failed or timed out, retrying in \(delay)s")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        guard let deviceID, !Task.isCancelled else {
            print("[Flow][RCM] runAutoConnect: cancelled before registration completed")
            return
        }

        registeredDeviceID = deviceID
        startHeartbeat()
        registerLifecycleObservers()
        observeSocketStatus()
        startConnectionWatchdog()

        #if canImport(AppKit)
        await listenForAllTrustedLinks(macID: deviceID)
        #else
        await connectToMostRecentTrustedLink(iphoneID: deviceID)
        monitorActiveConnection(iphoneID: deviceID)
        #endif
    }

    private func registerLifecycleObservers() {
        guard !lifecycleObserversRegistered else { return }
        lifecycleObserversRegistered = true

        #if canImport(AppKit)
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[Flow][RCM] NSWorkspace.didWakeNotification: forcing hard reconnect and local session rebuild")
            Task { @MainActor [weak self] in
                ConnectionManager.shared.recoverFromSystemWake()
                await self?.hardReconnect()
            }
        }

        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("[Flow][RCM] NSWorkspace.willSleepNotification: pausing background polling until wake")
            Task { @MainActor [weak self] in
                self?.linkPollTask?.cancel()
                self?.linkPollTask = nil
            }
        }
        print("[Flow][RCM] registerLifecycleObservers: NSWorkspace sleep/wake observers registered")
        #endif

        #if canImport(UIKit)
        print("[Flow][RCM] registerLifecycleObservers: UIKit foreground handling is driven by FlowConnectionRepository.handleAppForeground(), no separate observer needed here")
        #endif
    }

    private func maintainBackgroundActivity() {
        #if canImport(AppKit)
        guard backgroundActivityToken == nil else { return }
        backgroundActivityToken = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiated, .idleSystemSleepDisabled],
            reason: "Flow keeps this Mac reachable for local and remote control"
        )
        print("[Flow][RCM] maintainBackgroundActivity: began process activity, idle system sleep disabled for this process")
        #endif
    }

    private func observeSocketStatus() {
        socketStatusTask?.cancel()
        socketStatusTask = Task { [weak self] in
            guard let self else { return }
            var sawConnected = false
            for await status in SupabaseManager.shared.client.realtimeV2.statusChange {
                guard !Task.isCancelled else { return }
                print("[Flow][RCM] observeSocketStatus: realtime socket status=\(status)")
                switch status {
                case .connected:
                    sawConnected = true
                case .disconnected:
                    if sawConnected {
                        sawConnected = false
                        print("[Flow][RCM] observeSocketStatus: socket dropped after being connected, forcing hard reconnect")
                        await self.hardReconnect()
                    }
                case .connecting:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func startConnectionWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 45_000_000_000)
                guard !Task.isCancelled else { return }
                guard !self.isHardReconnecting else { continue }

                let socketStatus = SupabaseManager.shared.client.realtimeV2.status
                print("[Flow][RCM] watchdog: check state=\(self.state) socketStatus=\(socketStatus) activeChannelHealthy=\(self.activeChannel?.isHealthy ?? false)")

                if self.state == .connected, socketStatus != .connected {
                    print("[Flow][RCM] watchdog: socket status disagrees with connected state, forcing hard reconnect")
                    await self.hardReconnect()
                    continue
                }

                if self.state == .connected, let channel = self.activeChannel, !channel.isHealthy {
                    print("[Flow][RCM] watchdog: active channel unhealthy while connected, forcing hard reconnect")
                    await self.hardReconnect()
                    continue
                }
            }
        }
    }

    private func attemptSocketReconnect() async -> Bool {
        await withTaskGroup(of: Bool.self) { group in
            group.addTask { [weak self] in
                guard let self else { return false }
                _ = try? await self.backend.ensureRegisteredSession(
                    deviceName: self.localDeviceName,
                    deviceModel: self.localDeviceModel
                )
                await SupabaseManager.shared.client.realtimeV2.disconnect()
                await SupabaseManager.shared.client.realtimeV2.connect()
                return true
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    private func hardReconnect() async {
        guard !isPaused else {
            print("[Flow][RCM] hardReconnect: paused while local transport is active, skipping")
            return
        }
        guard !isHardReconnecting else {
            print("[Flow][RCM] hardReconnect: already in progress, skipping duplicate call")
            return
        }
        guard let deviceID = registeredDeviceID else {
            print("[Flow][RCM] hardReconnect: no registered device yet, falling back to startAutoConnect")
            startAutoConnect()
            return
        }
        isHardReconnecting = true
        defer { isHardReconnecting = false }

        print("[Flow][RCM] hardReconnect: begin deviceID=\(deviceID)")

        linkPollTask?.cancel()
        linkPollTask = nil
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil
        ackRetryTask?.cancel()
        ackRetryTask = nil
        #if canImport(UIKit)
        beaconTask?.cancel()
        beaconTask = nil
        #endif

        let staleActiveChannel = activeChannel
        let staleListeningChannels = listeningChannels
        listeningChannels.removeAll()
        activeChannel = nil
        activeLinkID = nil
        sendChain = nil
        resetFrameSendState()
        if state == .connected || state == .connecting {
            state = .disconnected
            connectedPeer = nil
        }
        if let staleActiveChannel {
            print("[Flow][RCM] hardReconnect: disconnecting stale active channel before rebuilding")
            await staleActiveChannel.disconnect()
        }
        for (id, channel) in staleListeningChannels where channel !== staleActiveChannel {
            print("[Flow][RCM] hardReconnect: disconnecting stale listening channel linkID=\(id)")
            await channel.disconnect()
        }

        var socketAttempt = 0
        var reconnected = false
        while !reconnected, !Task.isCancelled {
            socketAttempt += 1
            print("[Flow][RCM] hardReconnect: socket reconnect attempt \(socketAttempt)")
            reconnected = await attemptSocketReconnect()
            if !reconnected {
                let delay = min(Double(socketAttempt) * 2.0, 15.0)
                print("[Flow][RCM] hardReconnect: attempt \(socketAttempt) did not finish within timeout, retrying in \(delay)s")
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
        print("[Flow][RCM] hardReconnect: socket reconnect confirmed after \(socketAttempt) attempt(s)")
        observeSocketStatus()

        #if canImport(AppKit)
        await listenForAllTrustedLinks(macID: deviceID)
        #else
        await connectToMostRecentTrustedLink(iphoneID: deviceID)
        monitorActiveConnection(iphoneID: deviceID)
        #endif

        print("[Flow][RCM] hardReconnect: done")
    }

    #if canImport(AppKit)
    private func listenForAllTrustedLinks(macID: UUID) async {
        print("[Flow][RCM] listenForAllTrustedLinks: macID=\(macID)")
        await refreshTrustedLinks(macID: macID)
        linkPollTask?.cancel()
        linkPollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                guard !self.isPaused else { continue }
                await self.healListeningChannels()
                await self.refreshTrustedLinks(macID: macID)
            }
        }
    }

    private func healListeningChannels() async {
        for (linkID, channel) in listeningChannels {
            guard !channel.isHealthy else { continue }
            print("[Flow][RCM] healListeningChannels: linkID=\(linkID) channel is unhealthy, rebuilding")
            listeningChannels.removeValue(forKey: linkID)
            if activeLinkID == linkID {
                print("[Flow][RCM] healListeningChannels: linkID=\(linkID) was the active channel, dropping connected state")
                activeChannel = nil
                activeLinkID = nil
                sendChain = nil
                resetFrameSendState()
                if state == .connected {
                    state = .disconnected
                    connectedPeer = nil
                }
            }
            await channel.disconnect()
        }
    }

    private func refreshTrustedLinks(macID: UUID) async {
        guard let links = try? await backend.fetchTrustedLinks(macID: macID) else {
            print("[Flow][RCM] refreshTrustedLinks: fetchTrustedLinks FAILED or returned nil")
            return
        }
        print("[Flow][RCM] refreshTrustedLinks: found \(links.count) link(s) for macID=\(macID) -> \(links.map { $0.id })")
        for link in links {
            await beginListening(linkID: link.id, counterpartID: link.iphoneID)
        }
    }

    private func beginListening(linkID: UUID, counterpartID: UUID) async {
        guard listeningChannels[linkID] == nil else {
            print("[Flow][RCM] beginListening: linkID=\(linkID) already listening, skipping")
            return
        }
        print("[Flow][RCM] beginListening: linkID=\(linkID) counterpartID=\(counterpartID) creating channel")
        let channel = backend.makeChannel(deviceLinkID: linkID)
        listeningChannels[linkID] = channel

        channel.incoming
            .sink { [weak self] message in
                print("[Flow][RCM] beginListening: linkID=\(linkID) incoming message=\(message)")
                self?.handleIncoming(message, linkID: linkID, counterpartID: counterpartID)
            }
            .store(in: &cancellables)

        await channel.connect()
        print("[Flow][RCM] beginListening: linkID=\(linkID) channel.connect() returned")
    }

    private func acceptConnection(linkID: UUID, counterpartID: UUID) async {
        print("[Flow][RCM] acceptConnection: linkID=\(linkID) counterpartID=\(counterpartID) currentState=\(state) activeLinkID=\(activeLinkID?.uuidString ?? "nil")")
        guard let channel = listeningChannels[linkID] else {
            print("[Flow][RCM] acceptConnection: no listening channel for linkID=\(linkID), aborting")
            return
        }
        guard let myID = try? await SupabaseManager.shared.ensureSession() else {
            print("[Flow][RCM] acceptConnection: ensureSession FAILED, aborting")
            return
        }
        print("[Flow][RCM] acceptConnection: myID=\(myID)")

        let wasAlreadyConnected = state == .connected && activeLinkID == linkID

        if !wasAlreadyConnected {
            print("[Flow][RCM] acceptConnection: not yet connected on this link, fetching iPhone info and switching state")
            let info = try? await backend.fetchIPhoneInfo(id: counterpartID)
            print("[Flow][RCM] acceptConnection: fetchIPhoneInfo -> \(String(describing: info))")
            connectedPeer = DiscoveredPeer(
                peerID: MCPeerID(displayName: info?.deviceName ?? "iPhone"),
                deviceName: info?.deviceName ?? "iPhone",
                deviceModel: info?.deviceModel ?? "iPhone",
                platform: "iPhone",
                batteryLevel: -1,
                userName: info?.deviceName ?? "iPhone",
                profileImageData: nil,
                transport: .remote
            )

            for (id, other) in listeningChannels where id != linkID {
                print("[Flow][RCM] acceptConnection: disconnecting other listening channel linkID=\(id)")
                await other.disconnect()
            }
            listeningChannels = [linkID: channel]
            activeChannel = channel
            activeLinkID = linkID
            state = .connected
            resetFrameSendState()
        } else {
            print("[Flow][RCM] acceptConnection: already connected on this link, only re-sending ack")
        }

        ackRetryTask?.cancel()
        ackRetryTask = Task {
            for attempt in 0..<5 {
                guard !Task.isCancelled else {
                    print("[Flow][RCM] acceptConnection: ack retry cancelled at attempt \(attempt)")
                    return
                }
                print("[Flow][RCM] acceptConnection: sending remoteHandshakeAck attempt \(attempt + 1)/5 linkID=\(linkID)")
                await channel.send(.remoteHandshakeAck(deviceID: myID))
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
            print("[Flow][RCM] acceptConnection: ack retry loop finished linkID=\(linkID)")
        }
    }
    #endif

    #if canImport(UIKit)
    var connectedLinkID: UUID? {
        state == .connected ? activeLinkID : nil
    }

    func connect(linkID: UUID, macID: UUID) {
        print("[Flow][RCM] connect(linkID:macID:): linkID=\(linkID) macID=\(macID)")
        pairingError = nil
        Task { [weak self] in
            guard let self else { return }
            var myID = self.registeredDeviceID
            if myID == nil {
                myID = try? await self.ensureRegistered()
                self.registeredDeviceID = myID
            }
            guard let myID else {
                print("[Flow][RCM] connect(linkID:macID:): could not resolve own device ID, aborting")
                return
            }
            await self.beginHandshake(linkID: linkID, counterpartID: macID, myID: myID)
        }
    }

    func forget(linkID: UUID) async {
        print("[Flow][RCM] forget: linkID=\(linkID)")
        let wasActive = activeLinkID == linkID
        if wasActive {
            handshakeTimeoutTask?.cancel()
            handshakeTimeoutTask = nil
            ackRetryTask?.cancel()
            ackRetryTask = nil
            beaconTask?.cancel()
            beaconTask = nil
            let staleChannel = activeChannel
            activeChannel = nil
            activeLinkID = nil
            sendChain = nil
            resetFrameSendState()
            state = .disconnected
            connectedPeer = nil
            await staleChannel?.disconnect()
        }

        do {
            try await backend.revokeDeviceLink(id: linkID)
            print("[Flow][RCM] forget: revoked linkID=\(linkID)")
        } catch {
            print("[Flow][RCM] forget: revoke FAILED linkID=\(linkID) error=\(error)")
        }

        if wasActive, let deviceID = registeredDeviceID {
            await connectToMostRecentTrustedLink(iphoneID: deviceID)
        }
    }

    private func connectToMostRecentTrustedLink(iphoneID: UUID) async {
        print("[Flow][RCM] connectToMostRecentTrustedLink: iphoneID=\(iphoneID)")
        guard !isPaused else {
            print("[Flow][RCM] connectToMostRecentTrustedLink: paused while local transport is active, skipping")
            return
        }
        guard state == .disconnected else {
            print("[Flow][RCM] connectToMostRecentTrustedLink: state=\(state), a connection attempt is already active, skipping")
            return
        }
        guard let links = try? await backend.fetchTrustedLinks(iphoneID: iphoneID) else {
            print("[Flow][RCM] connectToMostRecentTrustedLink: fetchTrustedLinks FAILED or nil")
            return
        }
        print("[Flow][RCM] connectToMostRecentTrustedLink: found \(links.count) link(s)")
        guard let link = links.sorted(by: { $0.createdAt > $1.createdAt }).first else {
            print("[Flow][RCM] connectToMostRecentTrustedLink: no trusted links, nothing to do")
            return
        }
        await beginHandshake(linkID: link.id, counterpartID: link.macID, myID: iphoneID)
    }

    private func monitorActiveConnection(iphoneID: UUID) {
        linkPollTask?.cancel()
        linkPollTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                guard !self.isPaused else { continue }
                if self.state == .connected {
                    if let channel = self.activeChannel, !channel.isHealthy {
                        print("[Flow][RCM] monitorActiveConnection: active channel unhealthy, forcing hard reconnect")
                        await self.hardReconnect()
                    }
                } else if self.state == .disconnected {
                    await self.connectToMostRecentTrustedLink(iphoneID: iphoneID)
                }
            }
        }
    }

    private func performRedeem(code: String) async {
        print("[Flow][RCM] performRedeem: start code=\(code)")
        isPaused = false
        pairingError = nil
        state = .connecting
        do {
            let myID = try await backend.ensureRegisteredSession(
                deviceName: localDeviceName,
                deviceModel: localDeviceModel
            )
            print("[Flow][RCM] performRedeem: registered myID=\(myID)")
            let response = try await backend.redeemPairingCode(
                code: code,
                deviceName: localDeviceName,
                deviceModel: localDeviceModel
            )
            print("[Flow][RCM] performRedeem: redeemPairingCode SUCCEEDED linkID=\(response.deviceLinkID) macID=\(response.mac.id)")
            FlowDeviceIdentity.shared.remember(
                linkID: response.deviceLinkID,
                macName: response.mac.deviceName,
                macModel: response.mac.deviceModel
            )
            await beginHandshake(linkID: response.deviceLinkID, counterpartID: response.mac.id, myID: myID)
        } catch {
            print("[Flow][RCM] performRedeem: FAILED error=\(error)")
            state = .disconnected
            pairingError = "That code didn't work. Check it and try again."
        }
    }

    private func beginHandshake(linkID: UUID, counterpartID: UUID, myID: UUID) async {
        if activeLinkID == linkID, state == .connected {
            print("[Flow][RCM] beginHandshake: already connected to linkID=\(linkID), ignoring duplicate call")
            return
        }
        if activeLinkID == linkID, state == .connecting, activeChannel != nil, handshakeTimeoutTask != nil {
            print("[Flow][RCM] beginHandshake: handshake already in progress for linkID=\(linkID), ignoring duplicate call")
            return
        }

        print("[Flow][RCM] beginHandshake: linkID=\(linkID) counterpartID=\(counterpartID) myID=\(myID)")

        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil
        if let previousChannel = activeChannel {
            print("[Flow][RCM] beginHandshake: tearing down previous channel (linkID=\(activeLinkID?.uuidString ?? "nil")) before starting new handshake")
            activeChannel = nil
            activeLinkID = nil
            sendChain = nil
            resetFrameSendState()
            await previousChannel.disconnect()
        }

        state = .connecting
        let channel = backend.makeChannel(deviceLinkID: linkID)
        activeChannel = channel
        activeLinkID = linkID

        channel.incoming
            .sink { [weak self] message in
                print("[Flow][RCM] beginHandshake: linkID=\(linkID) incoming message=\(message)")
                self?.handleIncoming(message, linkID: linkID, counterpartID: counterpartID)
            }
            .store(in: &cancellables)

        await channel.connect()
        print("[Flow][RCM] beginHandshake: channel.connect() returned, starting handshake retry loop")

        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = Task { [weak self] in
            guard let self else { return }
            let deadline = Date().addingTimeInterval(45)
            var attempt = 0
            while !Task.isCancelled, self.state == .connecting, Date() < deadline {
                attempt += 1
                print("[Flow][RCM] beginHandshake: sending remoteHandshake attempt \(attempt) linkID=\(linkID)")
                await channel.send(.remoteHandshake(deviceID: myID))
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
            guard !Task.isCancelled, self.state == .connecting else {
                print("[Flow][RCM] beginHandshake: retry loop exiting normally, state=\(self.state) cancelled=\(Task.isCancelled)")
                return
            }
            print("[Flow][RCM] beginHandshake: TIMED OUT after \(attempt) attempts, giving up on linkID=\(linkID)")
            self.state = .disconnected
            self.pairingError = "Couldn't reach your Mac. Make sure Flow is open there."
            self.handshakeTimeoutTask = nil
        }
    }

    private func acceptAck(linkID: UUID, counterpartID: UUID) async {
        print("[Flow][RCM] acceptAck: linkID=\(linkID) counterpartID=\(counterpartID) activeLinkID=\(activeLinkID?.uuidString ?? "nil") activeChannel=\(activeChannel != nil)")
        guard activeLinkID == linkID, activeChannel != nil else {
            print("[Flow][RCM] acceptAck: linkID mismatch or no active channel, ignoring")
            return
        }
        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = nil
        pairingError = nil

        if state != .connected {
            print("[Flow][RCM] acceptAck: fetching mac info and marking connected")
            let info = try? await backend.fetchMacInfo(id: counterpartID)
            print("[Flow][RCM] acceptAck: fetchMacInfo -> \(String(describing: info))")
            connectedPeer = DiscoveredPeer(
                peerID: MCPeerID(displayName: info?.deviceName ?? "Mac"),
                deviceName: info?.deviceName ?? "Mac",
                deviceModel: info?.deviceModel ?? "Mac",
                platform: "Mac",
                batteryLevel: -1,
                userName: info?.deviceName ?? "Mac",
                profileImageData: nil,
                transport: .remote
            )
            state = .connected
            print("[Flow][RCM] acceptAck: state set to connected")
            requestInitialStateFromMac()
            startConnectedBeacon(linkID: linkID)
        } else {
            print("[Flow][RCM] acceptAck: already connected, ignoring duplicate ack")
        }
    }

    private func startConnectedBeacon(linkID: UUID) {
        beaconTask?.cancel()
        beaconTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                guard !Task.isCancelled else { return }
                guard self.state == .connected,
                      self.activeLinkID == linkID,
                      let channel = self.activeChannel,
                      let myID = self.registeredDeviceID
                else {
                    print("[Flow][RCM] startConnectedBeacon: conditions no longer hold for linkID=\(linkID), stopping")
                    return
                }
                print("[Flow][RCM] startConnectedBeacon: re-announcing handshake linkID=\(linkID)")
                await channel.send(.remoteHandshake(deviceID: myID))
            }
        }
    }

    private func requestInitialStateFromMac() {
        let delays: [Double] = [0.3, 1.0, 2.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.state == .connected else { return }
                self.send(.requestMacUserProfile)
            }
        }
    }
    #endif

    private func handleIncoming(_ message: FlowMessage, linkID: UUID, counterpartID: UUID) {
        switch message {
        case .remoteHandshake(let deviceID):
            print("[Flow][RCM] handleIncoming: remoteHandshake deviceID=\(deviceID) expectedCounterpart=\(counterpartID)")
            guard deviceID == counterpartID else {
                print("[Flow][RCM] handleIncoming: remoteHandshake deviceID MISMATCH, ignoring")
                return
            }
            #if canImport(AppKit)
            Task { await acceptConnection(linkID: linkID, counterpartID: counterpartID) }
            #endif

        case .remoteHandshakeAck(let deviceID):
            print("[Flow][RCM] handleIncoming: remoteHandshakeAck deviceID=\(deviceID) expectedCounterpart=\(counterpartID)")
            guard deviceID == counterpartID else {
                print("[Flow][RCM] handleIncoming: remoteHandshakeAck deviceID MISMATCH, ignoring")
                return
            }
            #if canImport(UIKit)
            Task { await acceptAck(linkID: linkID, counterpartID: counterpartID) }
            #endif

        default:
            guard state == .connected, linkID == activeLinkID else {
                print("[Flow][RCM] handleIncoming: dropping message=\(message), state=\(state) linkID=\(linkID) activeLinkID=\(activeLinkID?.uuidString ?? "nil")")
                return
            }
            #if canImport(AppKit)
            MacFeatureRepository.shared.handle(message) { [weak self] reply in
                self?.send(reply)
            }
            #else
            messageSubject.send(message)
            #endif
        }
    }

    private func startHeartbeat() {
        print("[Flow][RCM] startHeartbeat: launching")
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.backend.heartbeat()
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }

    private func stopHeartbeat() {
        print("[Flow][RCM] stopHeartbeat")
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    private var localDeviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #endif
    }

    private var localDeviceModel: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return resolvedMacModel()
        #endif
    }

    #if canImport(AppKit)
    private func resolvedMacModel() -> String {
        var size = 0
        let result1 = sysctlbyname("hw.model", nil, &size, nil, 0)
        guard result1 == 0, size > 0 else { return "Mac" }
        var buffer = [CChar](repeating: 0, count: size)
        let result2 = sysctlbyname("hw.model", &buffer, &size, nil, 0)
        guard result2 == 0 else { return "Mac" }
        let id = String(cString: buffer)
        if id.contains("MacBookPro") { return "MacBook Pro" }
        if id.contains("MacBookAir") { return "MacBook Air" }
        if id.contains("MacBook")    { return "MacBook" }
        if id.contains("MacMini")    { return "Mac mini" }
        if id.contains("MacPro")     { return "Mac Pro" }
        if id.contains("iMac")       { return "iMac" }
        return "Mac"
    }
    #endif
}
