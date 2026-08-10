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
    private let sendTimeoutNanos: UInt64 = 5_000_000_000

    private init() {}

    func attach(_ channel: RemoteMessageChannel?) {
        lock.lock()
        self.channel = channel
        slotBusy = false
        needsKeyframe = true
        sendDurationsMs.removeAll()
        targetBitRate = maxBitRate
        lock.unlock()
        print("[Flow][FrameTransport] attach: channel=\(channel == nil ? "nil" : "set") targetBitRate=\(maxBitRate)")
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
            let ok = await withTaskGroup(of: Bool.self) { group -> Bool in
                group.addTask { await activeChannel.send(message) }
                group.addTask {
                    try? await Task.sleep(nanoseconds: timeout)
                    return false
                }
                let first = await group.next() ?? false
                group.cancelAll()
                return first
            }
            let elapsedMs = Double(DispatchTime.now().uptimeNanoseconds - startedAt.uptimeNanoseconds) / 1_000_000
            self?.finishSend(success: ok, elapsedMs: elapsedMs)
        }
    }

    private func finishSend(success: Bool, elapsedMs: Double) {
        lock.lock()
        defer { lock.unlock() }
        slotBusy = false

        guard success else {
            needsKeyframe = true
            sendDurationsMs.removeAll()
            let previous = targetBitRate
            targetBitRate = max(minBitRate, targetBitRate - 400_000)
            print("[Flow][FrameTransport] finishSend: FAILED elapsedMs=\(elapsedMs) bitRate \(previous) -> \(targetBitRate), requesting keyframe")
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
            print("[Flow][FrameTransport] finishSend: avgSendMs=\(average) too slow, bitRate \(previous) -> \(targetBitRate)")
        } else if average < 120 {
            let previous = targetBitRate
            targetBitRate = min(maxBitRate, targetBitRate + 200_000)
            sendDurationsMs.removeAll()
            if previous != targetBitRate {
                print("[Flow][FrameTransport] finishSend: avgSendMs=\(average) healthy, bitRate \(previous) -> \(targetBitRate)")
            }
        }
    }
}