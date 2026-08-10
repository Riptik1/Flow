#if canImport(AppKit)
import AppKit
import CoreMedia
import Foundation
import ScreenCaptureKit
import WebRTC

final class RemoteAppMirroringHost: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    static let shared = RemoteAppMirroringHost()

    private let lock = NSLock()
    private nonisolated(unsafe) var stream: SCStream?
    private nonisolated(unsafe) var isRunning = false
    private nonisolated(unsafe) var targetWindowFrame: CGRect = .zero
    private nonisolated(unsafe) var currentWindowID: CGWindowID = 0
    private nonisolated(unsafe) var currentSessionID = UUID()
    private nonisolated(unsafe) var transport: WebRTCVideoTransport?
    private nonisolated(unsafe) var frameTimer: Timer?

    private override init() {
        super.init()
    }

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .startAppMirroring(let bundleID):
            startMirroring(bundleID: bundleID, reply: reply)

        case .stopAppMirroring:
            stopMirroring()

        case .appMirroringInputTouch(let phase, let x, let y):
            let frame = lockedValue { targetWindowFrame }
            AppMirroringInputInjector.shared.injectTouch(phase: phase, x: x, y: y, windowFrame: frame)

        case .appMirroringInputClick(let x, let y):
            let frame = lockedValue { targetWindowFrame }
            AppMirroringInputInjector.shared.injectClick(x: x, y: y, windowFrame: frame)

        case .appMirroringInputRightClick(let x, let y):
            let frame = lockedValue { targetWindowFrame }
            AppMirroringInputInjector.shared.injectRightClick(x: x, y: y, windowFrame: frame)

        case .appMirroringInputDoubleClick(let x, let y):
            let frame = lockedValue { targetWindowFrame }
            AppMirroringInputInjector.shared.injectDoubleClick(x: x, y: y, windowFrame: frame)

        case .appMirroringInputScroll(let dx, let dy):
            AppMirroringInputInjector.shared.injectScroll(deltaX: dx, deltaY: dy)

        case .appMirroringInputKey(let keyCode, let modifiers, let pressed):
            AppMirroringInputInjector.shared.injectKey(keyCode: keyCode, modifiers: modifiers, pressed: pressed)

        case .appMirroringInputText(let text):
            AppMirroringInputInjector.shared.injectText(text)

        case .appMirroringRemoteAnswer(let sdp):
            transport?.applyRemoteAnswer(sdp: sdp)

        case .appMirroringRemoteCandidate(let sdp, let sdpMLineIndex, let sdpMid):
            transport?.addRemoteCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)

        case .appMirroringRemoteEnd:
            stopMirroring()

        default:
            break
        }
    }

    private func lockedValue<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }; return body()
    }

    private func startMirroring(bundleID: String, reply: @escaping (FlowMessage) -> Void) {
        let sessionID = UUID()
        let previousStream = lockedValue { () -> SCStream? in
            let existing = stream
            stream = nil
            isRunning = false
            currentSessionID = sessionID
            currentWindowID = 0
            targetWindowFrame = .zero
            return existing
        }
        frameTimer?.invalidate()
        frameTimer = nil

        transport?.close()
        let newTransport = WebRTCVideoTransport(role: .offerer)
        transport = newTransport
        wireTransport(newTransport, reply: reply)

        Task {
            if let previousStream { try? await previousStream.stopCapture() }

            let alreadyRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                app.activate(options: [])
            } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            }
            if !alreadyRunning {
                try? await Task.sleep(nanoseconds: 4_500_000_000)
            }

            guard lockedValue({ currentSessionID == sessionID }) else { return }

            guard let window = try? await findBestWindow(bundleID: bundleID) else {
                reply(.appMirroringError(error: "Could not find a window for this app."))
                return
            }

            guard lockedValue({ currentSessionID == sessionID }) else { return }

            lockedValue {
                targetWindowFrame = window.frame
                currentWindowID = window.windowID
            }

            await buildStream(window: window, bundleID: bundleID, sessionID: sessionID, reply: reply)
            startWindowTracking(bundleID: bundleID, sessionID: sessionID)

            newTransport.createOffer { result in
                switch result {
                case .success(let sdp):
                    reply(.appMirroringRemoteOffer(sdp: sdp))
                case .failure:
                    reply(.appMirroringError(error: "Could not start the remote video session."))
                }
            }
        }
    }

    private func wireTransport(_ transport: WebRTCVideoTransport, reply: @escaping (FlowMessage) -> Void) {
        transport.onLocalCandidate = { candidate in
            reply(.appMirroringRemoteCandidate(
                sdp: candidate.sdp,
                sdpMLineIndex: candidate.sdpMLineIndex,
                sdpMid: candidate.sdpMid ?? ""
            ))
        }
        transport.onConnectionStateChange = { [weak self] state in
            guard state == .connected else { return }
            self?.lockedValue { self?.isRunning = true }
            reply(.appMirroringStarted)
        }
    }

    private func buildStream(window: SCWindow, bundleID: String, sessionID: UUID, reply: @escaping (FlowMessage) -> Void) async {
        let frame = window.frame
        let rawW = max(Int(frame.width), 2)
        let rawH = max(Int(frame.height), 2)
        let aspect = Double(rawW) / Double(rawH)
        var capW = min(rawW, 1920)
        var capH = max(2, Int(Double(capW) / aspect))
        capW = (capW / 2) * 2
        capH = (capH / 2) * 2

        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
              let display = Self.displayContaining(frame, in: content.displays) else {
            reply(.appMirroringError(error: "Could not locate the display for this window."))
            return
        }

        let sourceRect = CGRect(
            x: frame.origin.x - display.frame.origin.x,
            y: frame.origin.y - display.frame.origin.y,
            width: frame.width,
            height: frame.height
        )

        do {
            let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
            let config = SCStreamConfiguration()
            config.width = capW
            config.height = capH
            config.sourceRect = sourceRect
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.queueDepth = 3
            config.scalesToFit = true
            config.showsCursor = false
            config.pixelFormat = kCVPixelFormatType_32BGRA

            let captureQueue = DispatchQueue(
                label: "flow.remote.capture.\(sessionID.uuidString.prefix(8))",
                qos: .userInteractive
            )
            let newStream = SCStream(filter: filter, configuration: config, delegate: self)
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
            try await newStream.startCapture()

            guard lockedValue({ currentSessionID == sessionID }) else {
                try? await newStream.stopCapture()
                return
            }

            lockedValue {
                stream = newStream
                isRunning = true
            }

            reply(.appMirroringConfig(width: capW, height: capH, frameRate: 30, port: 0, host: ""))
            AppMirroringInputInjector.shared.hideCursor()
        } catch {
            reply(.appMirroringError(error: error.localizedDescription))
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid, let pixelBuffer = sampleBuffer.imageBuffer else { return }
        guard lockedValue({ isRunning }) else { return }
        transport?.pushCapturedFrame(pixelBuffer)
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        lockedValue { isRunning = false }
        AppMirroringInputInjector.shared.showCursor()
    }

    private func findBestWindow(bundleID: String) async throws -> SCWindow? {
        for attempt in 0..<20 {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            if let best = Self.selectBestWindow(from: content.windows, bundleID: bundleID) {
                return best
            }
            if attempt < 19 { try await Task.sleep(nanoseconds: 750_000_000) }
        }
        return nil
    }

    private static func displayContaining(_ rect: CGRect, in displays: [SCDisplay]) -> SCDisplay? {
        displays.max(by: {
            $0.frame.intersection(rect).width * $0.frame.intersection(rect).height <
            $1.frame.intersection(rect).width * $1.frame.intersection(rect).height
        })
    }

    private static func selectBestWindow(from windows: [SCWindow], bundleID: String) -> SCWindow? {
        let candidates = windows.filter {
            $0.owningApplication?.bundleIdentifier == bundleID
                && $0.isOnScreen
                && $0.frame.width >= 100
                && $0.frame.height >= 100
        }
        let titled = candidates.filter { !($0.title?.isEmpty ?? true) }
        let pool = titled.isEmpty ? candidates : titled
        return pool.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
    }

    private func startWindowTracking(bundleID: String, sessionID: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.frameTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self else { return }
                guard self.lockedValue({ self.isRunning && self.currentSessionID == sessionID }) else { return }
                Task {
                    guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else { return }
                    guard let best = Self.selectBestWindow(from: content.windows, bundleID: bundleID) else { return }
                    self.lockedValue {
                        self.targetWindowFrame = best.frame
                        self.currentWindowID = best.windowID
                    }
                }
            }
        }
    }

    private func stopMirroring() {
        let existingStream = lockedValue { () -> SCStream? in
            let existing = stream
            stream = nil
            isRunning = false
            targetWindowFrame = .zero
            currentWindowID = 0
            currentSessionID = UUID()
            return existing
        }
        frameTimer?.invalidate()
        frameTimer = nil
        AppMirroringInputInjector.shared.showCursor()
        transport?.close()
        transport = nil
        Task { try? await existingStream?.stopCapture() }
    }
}
#endif