//
//  RemoteMessageChannel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 13/07/26.
//

import Combine
import Foundation
import Supabase

enum FlowRealtimeEvent {
    static let name = "flow_message"
}

@MainActor
final class RemoteMessageChannel {
    let deviceLinkID: UUID

    private let channel: RealtimeChannelV2
    private var listenTask: Task<Void, Never>?
    private let incomingSubject = PassthroughSubject<FlowMessage, Never>()

    var incoming: AnyPublisher<FlowMessage, Never> {
        incomingSubject.eraseToAnyPublisher()
    }

    var isHealthy: Bool {
        channel.status == .subscribed
    }

    init(deviceLinkID: UUID, client: SupabaseClient) {
        self.deviceLinkID = deviceLinkID
        self.channel = client.channel("link:\(deviceLinkID.uuidString):flow") {
            $0.isPrivate = true
        }
        print("[Flow][Realtime] channel created linkID=\(deviceLinkID) topic=link:\(deviceLinkID.uuidString):flow")
    }

    func connect() async {
        print("[Flow][Realtime] connect: linkID=\(deviceLinkID) registering broadcastStream")
        let stream = channel.broadcastStream(event: FlowRealtimeEvent.name)
        listenTask = Task { [weak self] in
            guard let self else { return }
            for await raw in stream {
                print("[Flow][Realtime] connect: linkID=\(self.deviceLinkID) raw broadcast received: \(raw)")
                guard let flowMessage = Self.decode(raw) else {
                    print("[Flow][Realtime] connect: linkID=\(self.deviceLinkID) FAILED to decode FlowMessage from raw payload above")
                    continue
                }
                print("[Flow][Realtime] connect: linkID=\(self.deviceLinkID) decoded message=\(flowMessage)")
                self.incomingSubject.send(flowMessage)
            }
            print("[Flow][Realtime] connect: linkID=\(self.deviceLinkID) broadcastStream ended")
        }

        do {
            try await channel.subscribeWithError()
            print("[Flow][Realtime] connect: linkID=\(deviceLinkID) subscribeWithError SUCCEEDED status=\(channel.status)")
        } catch {
            print("[Flow][Realtime] connect: linkID=\(deviceLinkID) subscribeWithError FAILED error=\(error) status=\(channel.status)")
        }
    }

    @discardableResult
    func send(_ message: FlowMessage) async -> Bool {
        let approxBytes = (try? JSONEncoder().encode(message).count) ?? -1
        print("[Flow][Realtime] send: linkID=\(deviceLinkID) status=\(channel.status) approxBytes=\(approxBytes) message=\(message)")
        do {
            try await channel.broadcast(event: FlowRealtimeEvent.name, message: message)
            print("[Flow][Realtime] send: linkID=\(deviceLinkID) broadcast SUCCEEDED approxBytes=\(approxBytes)")
            return true
        } catch {
            print("[Flow][Realtime] send: linkID=\(deviceLinkID) broadcast FAILED approxBytes=\(approxBytes) error=\(error)")
            return false
        }
    }

    func disconnect() async {
        print("[Flow][Realtime] disconnect: linkID=\(deviceLinkID)")
        listenTask?.cancel()
        listenTask = nil
        await channel.unsubscribe()
        print("[Flow][Realtime] disconnect: linkID=\(deviceLinkID) unsubscribed")
    }

    private static func decode(_ raw: JSONObject) -> FlowMessage? {
        if let direct = try? AnyJSON.object(raw).decode(as: FlowMessage.self) {
            return direct
        }
        if let nested = raw["payload"], let decoded = try? nested.decode(as: FlowMessage.self) {
            return decoded
        }
        return nil
    }
}
