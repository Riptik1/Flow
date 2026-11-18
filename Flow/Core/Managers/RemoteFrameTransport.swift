//
//  RemoteFrameTransport.swift
//  Flow
//
//  Created by Riptik Jhajhria on 24/07/26.
//

import Foundation

final class RemoteFrameTransport {
    static let shared = RemoteFrameTransport()

    private let lock = NSLock()
    private var channel: RemoteMessageChannel?
    private var slotBusy = false
    private var needsKeyframe = true
    private var targetBitRate: Int32 = 2_500_000
    private var sendDurationsMs: [Double] = []
    private let maxBitRate: Int32 = 2_500_000
    private let minBitRate: Int32 = 350_000
    private let sendTimeoutNanos: UInt64 = 6_000_000_000

    private var consecutiveStalls = 0
    private let maxConsecutiveStalls = 2

    var onChannelStalled: (() -> Void)?

    private init() {}

    func attach(_ channel: RemoteMessageChannel?) {
        lock.lock()
        self.channel = channel
        slotBusy = false
        needsKeyframe = true
        sendDurationsMs.removeAll()
        targetBitRate = maxBitRate
        lock.unlock()
        flowLog("[Flow][FrameTransport] attach: channel=\(channel == nil ? "nil" : "set") targetBitRate=\(maxBitRate)")
    }

    func beginNewSession() {
        lock.lock()
        slotBusy = false
        needsKeyframe = true
        sendDurationsMs.removeAll()
        consecutiveStalls = 0
        lock.unlock()
        flowLog("[Flow][FrameTransport] beginNewSession: cleared any stale in-flight slot, forcing fresh keyframe")
    }

    func reserveSlot() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard channel != nil, !slotBusy else { return false }
        slotBusy = true
        return true
    }

    func releaseSlot() {
        lock.lock()
        slotBusy = false
        lock.unlock()
    }

    func consumeForceKeyframe() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let value = needsKeyframe
        needsKeyframe = false
        return value
    }

    func currentBitRate() -> Int32 {
        lock.lock()
        defer { lock.unlock() }
        return targetBitRate
    }

    func sendReservedFrame(_ message: FlowMessage) {
        lock.lock()
        let activeChannel = channel
        lock.unlock()

        guard let activeChannel else {
            releaseSlot()
            return
        }

        let startedAt = DispatchTime.now()
        let timeout = sendTimeoutNanos
        Task { [weak self] in
            let outcome = await withTaskGroup(of: Bool?.self) { group -> Bool? in
                group.addTask { Optional(await activeChannel.send(message)) }
                group.addTask {
                    try? await Task.sleep(nanoseconds: timeout)
                    return Bool?.none
                }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first
            }
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - startedAt.uptimeNanoseconds) / 1_000_000
            guard let self else { return }
            if let ok = outcome {
                self.finishSend(success: ok, elapsedMs: elapsedMs)
            } else {
                self.handleStalledSend(staleChannel: activeChannel, elapsedMs: elapsedMs)
            }
        }
    }

    private func handleStalledSend(staleChannel: RemoteMessageChannel, elapsedMs: Double) {
        lock.lock()
        let stillCurrent = channel === staleChannel
        guard stillCurrent else {
            lock.unlock()
            return
        }

        slotBusy = false
        needsKeyframe = true
        sendDurationsMs.removeAll()
        consecutiveStalls += 1
        let stalls = consecutiveStalls

        guard stalls >= maxConsecutiveStalls else {
            lock.unlock()
            flowLog("[Flow][FrameTransport] sendReservedFrame: stall #\(stalls) after \(elapsedMs)ms, dropping this frame and requesting a fresh keyframe, not reconnecting yet")
            return
        }

        channel = nil
        consecutiveStalls = 0
        lock.unlock()
        flowLog("[Flow][FrameTransport] sendReservedFrame: \(stalls) consecutive stalls, retiring this channel and requesting a reconnect")
        onChannelStalled?()
    }

    private func finishSend(success: Bool, elapsedMs: Double) {
        lock.lock()
        defer { lock.unlock() }
        slotBusy = false
        consecutiveStalls = 0

        guard success else {
            needsKeyframe = true
            sendDurationsMs.removeAll()
            let previous = targetBitRate
            targetBitRate = max(minBitRate, targetBitRate - 400_000)
            flowLog("[Flow][FrameTransport] finishSend: FAILED elapsedMs=\(elapsedMs) bitRate \(previous) -> \(targetBitRate), requesting keyframe")
            return
        }

        sendDurationsMs.append(elapsedMs)
        if sendDurationsMs.count > 6 { sendDurationsMs.removeFirst() }
        guard sendDurationsMs.count >= 4 else { return }

        let average = sendDurationsMs.reduce(0, +) / Double(sendDurationsMs.count)
        if average > 300 {
            let previous = targetBitRate
            targetBitRate = max(minBitRate, targetBitRate - 300_000)
            sendDurationsMs.removeAll()
            flowLog("[Flow][FrameTransport] finishSend: avgSendMs=\(average) too slow, bitRate \(previous) -> \(targetBitRate)")
        } else if average < 120 {
            let previous = targetBitRate
            targetBitRate = min(maxBitRate, targetBitRate + 200_000)
            sendDurationsMs.removeAll()
            if previous != targetBitRate {
                flowLog("[Flow][FrameTransport] finishSend: avgSendMs=\(average) healthy, bitRate \(previous) -> \(targetBitRate)")
            }
        }
    }
}
