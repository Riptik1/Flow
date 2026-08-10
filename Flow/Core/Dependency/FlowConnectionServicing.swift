//
//  FlowConnectionServicing.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import Foundation

protocol FlowConnectionServicing: AnyObject {
    var messageStream: AnyPublisher<FlowMessage, Never> { get }
    var isConnected: Bool { get }
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
    func send(_ message: FlowMessage)
    func startAutoConnect()
    func handleAppForeground()
}

final class LiveFlowConnectionService: FlowConnectionServicing {
    static let shared = LiveFlowConnectionService()

    private let relay = PassthroughSubject<FlowMessage, Never>()
    private var upstreamSubscription: AnyCancellable?

    private init() {
        upstreamSubscription = FlowConnectionRepository.shared.messageStream
            .sink { [relay] message in relay.send(message) }
    }

    var messageStream: AnyPublisher<FlowMessage, Never> {
        relay.eraseToAnyPublisher()
    }

    var isConnected: Bool {
        FlowConnectionRepository.shared.state == .connected
    }

    var isConnectedPublisher: AnyPublisher<Bool, Never> {
        FlowConnectionRepository.shared.$state
            .map { $0 == .connected }
            .eraseToAnyPublisher()
    }

    func send(_ message: FlowMessage) {
        FlowConnectionRepository.shared.send(message)
    }

    func startAutoConnect() {
        FlowConnectionRepository.shared.startAutoConnect()
    }

    func handleAppForeground() {
        FlowConnectionRepository.shared.handleAppForeground()
    }
}
