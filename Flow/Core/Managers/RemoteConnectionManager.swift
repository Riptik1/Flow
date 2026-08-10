//
//  RemoteConnectionManager.swift
//  Flow
//
//  Created by Riptik Jhajhria on 13/07/26.
//

import Combine
import Foundation
import MultipeerConnectivity

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
import Darwin
#endif

@MainActor
final class RemoteConnectionManager: ObservableObject {
    static let shared = RemoteConnectionManager()

    @Published var state: FlowConnectionState = .disconnected
    @Published var connectedPeer: DiscoveredPeer? = nil

    private let service = RemoteSupabaseService.shared
    private let messageSubject = PassthroughSubject<FlowMessage, Never>()

    var messageStream: AnyPublisher<FlowMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    private var cancellables = Set<AnyCancellable>()
    private var listeningChannels: [UUID: RemoteMessageChannel] = [:]
    private var activeChannel: RemoteMessageChannel?
    private var activeLinkID: UUID?

    private var autoConnectTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var handshakeTimeoutTask: Task<Void, Never>?

    private init() {}

    func startAutoConnect() {
        guard autoConnectTask == nil else { return }
        autoConnectTask = Task { [weak self] in
            await self?.runAutoConnect()
            self?.autoConnectTask = nil
        }
    }

    func handleAppForeground() {
        if state == .disconnected {
            startAutoConnect()
        }
    }

    func send(_ message: FlowMessage) {
        guard let channel = activeChannel else { return }
        Task { await channel.send(message) }
    }

    func disconnect() {
        Task {
            await activeChannel?.disconnect()
            for (_, channel) in listeningChannels {
                await channel.disconnect()
            }
            listeningChannels.removeAll()
            activeChannel = nil
            activeLinkID = nil
            connectedPeer = nil
            state = .disconnected
            stopHeartbeat()
        }
    }

    private func runAutoConnect() async {
        let deviceID: UUID
        do {
            deviceID = try await service.ensureRegisteredSession(
                deviceName: localDeviceName,
                deviceModel: localDeviceModel
            )
        } catch {
            return
        }

        startHeartbeat()

        #if canImport(AppKit)
        await listenForAllTrustedLinks(macID: deviceID)
        #else
        await connectToMostRecentTrustedLink(iphoneID: deviceID)
        #endif
    }

    #if canImport(AppKit)
    private func listenForAllTrustedLinks(macID: UUID) async {
        guard let links = try? await service.fetchTrustedLinks(macID: macID) else { return }
        for link in links {
            await beginListening(linkID: link.id, counterpartID: link.iphoneID)
        }
    }

    private func beginListening(linkID: UUID, counterpartID: UUID) async {
        guard listeningChannels[linkID] == nil else { return }
        let channel = service.makeChannel(deviceLinkID: linkID)
        listeningChannels[linkID] = channel

        channel.incoming
            .sink { [weak self] message in
                self?.handleIncoming(message, linkID: linkID, counterpartID: counterpartID)
            }
            .store(in: &cancellables)

        try? await channel.connect()
    }

    private func acceptConnection(linkID: UUID, counterpartID: UUID) async {
        guard state != .connected, let channel = listeningChannels[linkID] else { return }
        guard let myID = try? await service.ensureSession() else { return }

        await channel.send(.remoteHandshakeAck(deviceID: myID))

        let info = try? await service.fetchIPhoneInfo(id: counterpartID)
        connectedPeer = DiscoveredPeer(
            peerID: MCPeerID(displayName: info?.deviceName ?? "iPhone"),
            deviceName: info?.deviceName ?? "iPhone",
            deviceModel: info?.deviceModel ?? "iPhone",
            platform: "iPhone",
            batteryLevel: -1,
            userName: info?.deviceName ?? "iPhone",
            profileImageData: nil
        )

        for (id, other) in listeningChannels where id != linkID {
            await other.disconnect()
        }
        listeningChannels = [linkID: channel]
        activeChannel = channel
        activeLinkID = linkID
        state = .connected
    }
    #endif

    #if canImport(UIKit)
    private func connectToMostRecentTrustedLink(iphoneID: UUID) async {
        guard let links = try? await service.fetchTrustedLinks(iphoneID: iphoneID),
              let link = links.sorted(by: { $0.createdAt > $1.createdAt }).first
        else { return }

        state = .connecting
        let channel = service.makeChannel(deviceLinkID: link.id)
        activeChannel = channel
        activeLinkID = link.id

        channel.incoming
            .sink { [weak self] message in
                self?.handleIncoming(message, linkID: link.id, counterpartID: link.macID)
            }
            .store(in: &cancellables)

        try? await channel.connect()
        await channel.send(.remoteHandshake(deviceID: iphoneID))

        handshakeTimeoutTask?.cancel()
        handshakeTimeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let self, self.state == .connecting else { return }
            self.state = .disconnected
        }
    }

    private func acceptAck(linkID: UUID, counterpartID: UUID) async {
        guard activeLinkID == linkID, activeChannel != nil else { return }
        handshakeTimeoutTask?.cancel()

        let info = try? await service.fetchMacInfo(id: counterpartID)
        connectedPeer = DiscoveredPeer(
            peerID: MCPeerID(displayName: info?.deviceName ?? "Mac"),
            deviceName: info?.deviceName ?? "Mac",
            deviceModel: info?.deviceModel ?? "Mac",
            platform: "Mac",
            batteryLevel: -1,
            userName: info?.deviceName ?? "Mac",
            profileImageData: nil
        )
        state = .connected
    }
    #endif

    private func handleIncoming(_ message: FlowMessage, linkID: UUID, counterpartID: UUID) {
        switch message {
        case .remoteHandshake(let deviceID):
            guard deviceID == counterpartID else { return }
            #if canImport(AppKit)
            Task { await acceptConnection(linkID: linkID, counterpartID: counterpartID) }
            #endif

        case .remoteHandshakeAck(let deviceID):
            guard deviceID == counterpartID else { return }
            #if canImport(UIKit)
            Task { await acceptAck(linkID: linkID, counterpartID: counterpartID) }
            #endif

        default:
            guard state == .connected, linkID == activeLinkID else { return }
            messageSubject.send(message)
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                await self.service.heartbeat()
                try? await Task.sleep(nanoseconds: 20_000_000_000)
            }
        }
    }

    private func stopHeartbeat() {
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