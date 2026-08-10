//
//  BackTapEngine.swift
//  Flow
//
//  Created by Riptik Jhajhria on 08/06/26.
//

import CoreMotion
import Combine

final class BackTapEngine: ObservableObject {
    static let shared = BackTapEngine()

    var isAvailable: Bool { motion.isAccelerometerAvailable }
    var onGesture: ((BackTapKind) -> Void)?
    var onRawTap:  (() -> Void)?

    private let motion    = CMMotionManager()
    private let queue     = OperationQueue()
    private var tapTimes: [TimeInterval] = []
    private var evalTimer: Timer?
    private var lastPeakTime: TimeInterval = 0
    private var inPeak     = false
    private var isRunning  = false

    private static let sampleRate:   TimeInterval = 1.0 / 200.0
    private static let peakThresh:   Double       = 1.35
    private static let resetThresh:  Double       = 0.95
    private static let minTapGap:    TimeInterval = 0.12
    private static let maxTapGap:    TimeInterval = 0.55
    private static let evalDelay:    TimeInterval = 0.70
    private static let maxWindowLen: TimeInterval = 2.0

    private init() {
        queue.name            = "flow.backtap"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
    }

    func startGlobal() {
        guard isAvailable, !isRunning else { return }
        isRunning    = true
        tapTimes     = []
        lastPeakTime = 0
        inPeak       = false

        motion.accelerometerUpdateInterval = Self.sampleRate
        motion.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            self.process(data.acceleration)
        }
    }

    func stopGlobal() {
        guard isRunning else { return }
        isRunning = false
        motion.stopAccelerometerUpdates()
        cancelEval()
        tapTimes = []
        inPeak   = false
    }

    private func process(_ a: CMAcceleration) {
        let mag = sqrt(a.x*a.x + a.y*a.y + a.z*a.z)
        let now = ProcessInfo.processInfo.systemUptime

        if mag > Self.peakThresh && !inPeak {
            let gap = now - lastPeakTime
            guard gap >= Self.minTapGap else { return }

            if !tapTimes.isEmpty && gap > Self.maxTapGap {
                tapTimes = []
            }

            if tapTimes.isEmpty || now - (tapTimes.first ?? now) < Self.maxWindowLen {
                inPeak       = true
                lastPeakTime = now
                tapTimes.append(now)
                DispatchQueue.main.async { self.onRawTap?() }
                scheduleEval()
            }

        } else if mag < Self.resetThresh {
            inPeak = false
        }
    }

    private func scheduleEval() {
        cancelEval()
        evalTimer = Timer.scheduledTimer(
            withTimeInterval: Self.evalDelay,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            let count = self.tapTimes.count
            self.tapTimes = []
            self.inPeak   = false
            let kind: BackTapKind?
            switch count {
            case 2: kind = .doubleTap
            case 3: kind = .tripleTap
            case 4: kind = .quadTap
            default: kind = nil
            }
            if let kind { self.onGesture?(kind) }
        }
        RunLoop.main.add(evalTimer!, forMode: .common)
    }

    private func cancelEval() {
        evalTimer?.invalidate()
        evalTimer = nil
    }
}
