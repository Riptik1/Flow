//
//  FlowLog.swift
//  Flow
//
//  Debug-only logging. In Release builds nothing is evaluated or printed, so
//  pairing codes, passwords and clipboard contents never reach the console.
//

import Foundation

@inline(__always)
nonisolated func flowLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print(message())
    #endif
}

extension FlowMessage {
    /// Case name only (never the payload) – safe to log.
    nonisolated var logLabel: String {
        if let label = Mirror(reflecting: self).children.first?.label { return label }
        return String(describing: self)
    }
}
