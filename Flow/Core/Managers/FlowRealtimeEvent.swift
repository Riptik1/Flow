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

    init(deviceLinkID: UUID, client: SupabaseClient) {
        self.deviceLinkID = deviceLinkID
        self.channel = client.channel("link:\(deviceLinkID.uuidString):flow") {
            $0.isPrivate = true
        }
    }

    func connect() async {
        let stream = channel.broadcastStream(event: FlowRealtimeEvent.name)
        listenTask = Task { [weak self] in
            for await raw in stream {
                guard let flowMessage = Self.decode(raw) else { continue }
                self?.incomingSubject.send(flowMessage)
            }
        }
        await channel.subscribe()
    }

    func send(_ message: FlowMessage) async {
        try? await channel.broadcast(event: FlowRealtimeEvent.name, message: message)
    }

    func disconnect() async {
        listenTask?.cancel()
        listenTask = nil
        await channel.unsubscribe()
    }

    // The Realtime envelope shape has been inconsistent across supabase-swift's
    // own docs (some show the raw dict, some show it nested under "payload").
    // Try both so this keeps working regardless of which is true for your
    // installed version.
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