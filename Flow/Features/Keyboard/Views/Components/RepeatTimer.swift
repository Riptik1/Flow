//
//  RepeatTimer.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import Combine
import Foundation

final class RepeatTimer {
    private var a: DispatchWorkItem?
    private var b: DispatchWorkItem?

    func start(delay: TimeInterval = 0.45, interval: TimeInterval = 0.05, fn: @escaping () -> Void) {
        cancel(); fn()
        let w = DispatchWorkItem { [weak self] in self?.rep(interval: interval, fn: fn) }
        a = w; DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: w)
    }

    private func rep(interval: TimeInterval, fn: @escaping () -> Void) {
        fn()
        let w = DispatchWorkItem { [weak self] in self?.rep(interval: interval, fn: fn) }
        b = w; DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: w)
    }

    func cancel() { a?.cancel(); b?.cancel(); a = nil; b = nil }
}

final class RT: ObservableObject {
    let t = RepeatTimer()
}
