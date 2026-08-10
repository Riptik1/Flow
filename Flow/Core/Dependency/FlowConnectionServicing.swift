//
//  FlowConnectionServicing.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//


protocol FlowConnectionServicing: AnyObject {
    var messageStream: AnyPublisher<FlowMessage, Never> { get }
    var isConnected: Bool { get }
    var isConnectedPublisher: AnyPublisher<Bool, Never> { get }
    func send(_ message: FlowMessage)
}
