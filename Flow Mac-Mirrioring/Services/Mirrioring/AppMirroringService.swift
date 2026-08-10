//
//  AppMirroringService.swift
//  Flow
//
//  Created by Riptik Jhajhria on 07/06/26.
//

import ScreenCaptureKit
import CoreMedia
import AppKit
import VideoToolbox

final class AppMirroringService: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    static let shared = AppMirroringService()

    private let lock = NSLock()
    nonisolated(unsafe) private var stream: SCStream?
    nonisolated(unsafe) private var isRunning = false
    nonisolated(unsafe) private var targetWindowFrame: CGRect = .zero
    nonisolated(unsafe) private var replyBlock: ((FlowMessage) -> Void)?
    nonisolated(unsafe) private var currentSessionID: UUID = UUID()
    nonisolated(unsafe) private var currentWindowID: CGWindowID = 0
    nonisolated(unsafe) private var compressionSession: VTCompressionSession?
    nonisolated(unsafe) private var currentCapW: Int = 0
    nonisolated(unsafe) private var currentCapH: Int = 0

    private var frameTimer: Timer?

    private let encodeSemaphore = DispatchSemaphore(value: 2)

    nonisolated(unsafe) private var lastEncodedAt: CFTimeInterval = 0
    private let targetFrameRate: Int = 60
    private let minFrameInterval: CFTimeInterval = 1.0 / 60.0

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .startAppMirroring(let bundleID):
            startMirroring(bundleID: bundleID, reply: reply)
        case .stopAppMirroring:
            stopMirroring()
        case .appMirroringInputTouch(let phase, let x, let y):
            let frame = lock.withLockUnchecked { targetWindowFrame }
            AppMirroringInputInjector.shared.injectTouch(phase: phase, x: x, y: y, windowFrame: frame)
        case .appMirroringInputClick(let x, let y):
            let frame = lock.withLockUnchecked { targetWindowFrame }
            AppMirroringInputInjector.shared.injectClick(x: x, y: y, windowFrame: frame)
        case .appMirroringInputScroll(let dx, let dy):
            AppMirroringInputInjector.shared.injectScroll(deltaX: dx, deltaY: dy)
        case .appMirroringInputKey(let keyCode, let modifiers, let pressed):
            AppMirroringInputInjector.shared.injectKey(keyCode: keyCode, modifiers: modifiers, pressed: pressed)
        case .appMirroringInputRightClick(let x, let y):
            let frame = lock.withLockUnchecked { targetWindowFrame }
            AppMirroringInputInjector.shared.injectRightClick(x: x, y: y, windowFrame: frame)
        case .appMirroringInputDoubleClick(let x, let y):
            let frame = lock.withLockUnchecked { targetWindowFrame }
            AppMirroringInputInjector.shared.injectDoubleClick(x: x, y: y, windowFrame: frame)
        case .appMirroringInputText(let text):
            AppMirroringInputInjector.shared.injectText(text)
        default:
            break
        }
    }

    private func startMirroring(bundleID: String, reply: @escaping (FlowMessage) -> Void) {
        let sessionID = UUID()
        let (oldStream, oldSession) = lock.withLockUnchecked { () -> (SCStream?, VTCompressionSession?) in
            let s = self.stream
            let c = self.compressionSession
            self.stream = nil
            self.compressionSession = nil
            self.isRunning = false
            self.replyBlock = nil
            self.lastEncodedAt = 0
            self.currentSessionID = sessionID
            self.currentWindowID = 0
            return (s, c)
        }
        if let oldSession {
            VTCompressionSessionInvalidate(oldSession)
        }

        stopObservers()

        Task {
            if let s = oldStream {
                try? await s.stopCapture()
            }

            let isAlreadyRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                app.activate(options: [])
            } else {
                await MainActor.run { AppLaunchService.shared.launch(bundleID: bundleID) }
            }

            if !isAlreadyRunning {
                try? await Task.sleep(nanoseconds: 4_500_000_000)
            }

            guard lock.withLockUnchecked({ self.currentSessionID == sessionID }) else { return }

            guard let window = try? await findBestWindow(bundleID: bundleID) else {
                reply(.appMirroringError(error: "Could not find a window for this app."))
                return
            }

            guard lock.withLockUnchecked({ self.currentSessionID == sessionID }) else { return }

            lock.withLockUnchecked {
                self.targetWindowFrame = window.frame
                self.currentWindowID = window.windowID
                self.replyBlock = reply
            }

            await MainActor.run {
                self.startObservers(bundleID: bundleID, sessionID: sessionID)
            }

            await buildStream(window: window, bundleID: bundleID, sessionID: sessionID, reply: reply)
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

        guard let newSession = Self.makeCompressionSession(width: Int32(capW), height: Int32(capH), frameRate: targetFrameRate) else {
            reply(.appMirroringError(error: "Could not create the video encoder."))
            return
        }

        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
              let display = Self.displayContaining(frame, in: content.displays) else {
            VTCompressionSessionInvalidate(newSession)
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
            config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(targetFrameRate))
            config.queueDepth = 3
            config.scalesToFit = true
            config.showsCursor = false
            config.pixelFormat = kCVPixelFormatType_32BGRA

            let captureQueue = DispatchQueue(
                label: "flow.capture.\(sessionID.uuidString.prefix(8))",
                qos: .userInteractive
            )
            let newStream = SCStream(filter: filter, configuration: config, delegate: self)
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
            try await newStream.startCapture()

            guard lock.withLockUnchecked({ self.currentSessionID == sessionID }) else {
                try? await newStream.stopCapture()
                VTCompressionSessionInvalidate(newSession)
                return
            }

            let oldSession = lock.withLockUnchecked { () -> VTCompressionSession? in
                let old = self.compressionSession
                self.stream = newStream
                self.compressionSession = newSession
                self.isRunning = true
                self.lastEncodedAt = 0
                self.currentCapW = capW
                self.currentCapH = capH
                return old
            }
            if let oldSession {
                VTCompressionSessionInvalidate(oldSession)
            }

            reply(.appMirroringConfig(width: capW, height: capH, frameRate: targetFrameRate, port: 0, host: ""))
            reply(.appMirroringStarted)
            AppMirroringInputInjector.shared.hideCursor()
        } catch {
            VTCompressionSessionInvalidate(newSession)
            reply(.appMirroringError(error: error.localizedDescription))
        }
    }

    private func updateSourceRect(for frame: CGRect, sessionID: UUID) async {
        guard lock.withLockUnchecked({ self.currentSessionID == sessionID }),
              let stream = lock.withLockUnchecked({ self.stream }) else { return }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
              let display = Self.displayContaining(frame, in: content.displays) else { return }

        let sourceRect = CGRect(
            x: frame.origin.x - display.frame.origin.x,
            y: frame.origin.y - display.frame.origin.y,
            width: frame.width,
            height: frame.height
        )

        let (capW, capH) = lock.withLockUnchecked { (self.currentCapW, self.currentCapH) }
        guard capW > 0, capH > 0 else { return }

        let config = SCStreamConfiguration()
        config.width = capW
        config.height = capH
        config.sourceRect = sourceRect
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(targetFrameRate))
        config.queueDepth = 3
        config.scalesToFit = true
        config.showsCursor = false
        config.pixelFormat = kCVPixelFormatType_32BGRA

        guard lock.withLockUnchecked({ self.currentSessionID == sessionID }) else { return }
        try? await stream.updateConfiguration(config)
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

    private static func makeCompressionSession(width: Int32, height: Int32, frameRate: Int) -> VTCompressionSession? {
        let imageBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]

        var session: VTCompressionSession?
        let status = VTCompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            width: width,
            height: height,
            codecType: kCMVideoCodecType_H264,
            encoderSpecification: nil,
            imageBufferAttributes: imageBufferAttributes as CFDictionary,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: &session
        )
        guard status == noErr, let session else { return nil }

        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_RealTime, value: kCFBooleanTrue)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AllowFrameReordering, value: kCFBooleanFalse)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ProfileLevel, value: kVTProfileLevel_H264_Baseline_AutoLevel)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameInterval, value: Int32(frameRate * 2) as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration, value: 2.0 as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: 8_000_000 as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: Int32(frameRate) as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(session)
        return session
    }

    private func startObservers(bundleID: String, sessionID: UUID) {
        frameTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self else { return }
            guard self.lock.withLockUnchecked({ self.isRunning && self.currentSessionID == sessionID }) else { return }
            Task {
                guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else { return }
                guard let best = Self.selectBestWindow(from: content.windows, bundleID: bundleID) else { return }

                let knownID = self.lock.withLockUnchecked { self.currentWindowID }
                if best.windowID != knownID {
                    self.lock.withLockUnchecked {
                        self.targetWindowFrame = best.frame
                        self.currentWindowID = best.windowID
                    }
                    await self.switchToNewWindow(window: best, bundleID: bundleID, sessionID: sessionID)
                } else {
                    let previousFrame = self.lock.withLockUnchecked { self.targetWindowFrame }
                    self.lock.withLockUnchecked { self.targetWindowFrame = best.frame }
                    if previousFrame != best.frame {
                        await self.updateSourceRect(for: best.frame, sessionID: sessionID)
                    }
                }
            }
        }
    }

    private func stopObservers() {
        frameTimer?.invalidate()
        frameTimer = nil
    }

    private func switchToNewWindow(window: SCWindow, bundleID: String, sessionID: UUID) async {
        let (oldStream, oldSession) = lock.withLockUnchecked { () -> (SCStream?, VTCompressionSession?) in
            guard self.currentSessionID == sessionID else { return (nil, nil) }
            let s = self.stream
            let c = self.compressionSession
            self.stream = nil
            self.compressionSession = nil
            self.isRunning = false
            self.lastEncodedAt = 0
            return (s, c)
        }
        guard let oldStream else { return }
        if let oldSession {
            VTCompressionSessionInvalidate(oldSession)
        }
        try? await oldStream.stopCapture()

        guard lock.withLockUnchecked({ self.currentSessionID == sessionID }) else { return }

        let reply = lock.withLockUnchecked { self.replyBlock }
        guard let reply else { return }

        await buildStream(window: window, bundleID: bundleID, sessionID: sessionID, reply: reply)
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

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen,
              sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer else { return }

        lock.lock()
        guard isRunning, let session = compressionSession else { lock.unlock(); return }
        let now = CACurrentMediaTime()
        let elapsed = now - lastEncodedAt
        guard elapsed >= minFrameInterval else { lock.unlock(); return }
        lastEncodedAt = now
        let reply = replyBlock
        lock.unlock()

        guard let reply else { return }
        guard encodeSemaphore.wait(timeout: .now()) == .success else { return }

        let pts = CMTime(seconds: now, preferredTimescale: 1_000_000)
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: .invalid,
            frameProperties: nil,
            infoFlagsOut: nil
        ) { [weak self] encodeStatus, _, encodedSampleBuffer in
            defer { self?.encodeSemaphore.signal() }
            guard encodeStatus == noErr,
                  let encodedSampleBuffer,
                  CMSampleBufferDataIsReady(encodedSampleBuffer),
                  let annexB = Self.annexBData(from: encodedSampleBuffer) else { return }
            reply(.appMirroringFrame(data: annexB, timestamp: now))
        }
        if status != noErr {
            encodeSemaphore.signal()
        }
    }

    private static func isKeyframe(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[CFString: Any]],
              let attachments = attachmentsArray.first else { return true }
        return (attachments[kCMSampleAttachmentKey_NotSync] as? Bool) != true
    }

    private static func annexBData(from sampleBuffer: CMSampleBuffer) -> Data? {
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return nil }
        var totalLength = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        guard CMBlockBufferGetDataPointer(dataBuffer, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &totalLength, dataPointerOut: &dataPointer) == noErr,
              let dataPointer else { return nil }

        var result = Data()
        let startCode: [UInt8] = [0, 0, 0, 1]

        if isKeyframe(sampleBuffer), let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) {
            var parameterSetCount = 0
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                formatDescription, parameterSetIndex: 0,
                parameterSetPointerOut: nil, parameterSetSizeOut: nil,
                parameterSetCountOut: &parameterSetCount, nalUnitHeaderLengthOut: nil
            )
            for i in 0..<parameterSetCount {
                var parameterSetPointer: UnsafePointer<UInt8>?
                var parameterSetSize = 0
                guard CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                    formatDescription, parameterSetIndex: i,
                    parameterSetPointerOut: &parameterSetPointer, parameterSetSizeOut: &parameterSetSize,
                    parameterSetCountOut: nil, nalUnitHeaderLengthOut: nil
                ) == noErr, let parameterSetPointer else { continue }
                result.append(contentsOf: startCode)
                result.append(UnsafeBufferPointer(start: parameterSetPointer, count: parameterSetSize))
            }
        }

        let raw = UnsafeRawBufferPointer(start: dataPointer, count: totalLength)
        var offset = 0
        while offset + 4 <= totalLength {
            let nalLength = Int(UInt32(raw[offset]) << 24 | UInt32(raw[offset + 1]) << 16 | UInt32(raw[offset + 2]) << 8 | UInt32(raw[offset + 3]))
            let nalStart = offset + 4
            let nalEnd = nalStart + nalLength
            guard nalLength > 0, nalEnd <= totalLength else { break }
            result.append(contentsOf: startCode)
            result.append(contentsOf: raw[nalStart..<nalEnd])
            offset = nalEnd
        }

        return result
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        lock.withLockUnchecked { isRunning = false }
        AppMirroringInputInjector.shared.showCursor()
    }

    private func stopMirroring() {
        let (s, session) = lock.withLockUnchecked { () -> (SCStream?, VTCompressionSession?) in
            let s = self.stream
            let session = self.compressionSession
            self.stream = nil
            self.compressionSession = nil
            self.isRunning = false
            self.targetWindowFrame = .zero
            self.replyBlock = nil
            self.lastEncodedAt = 0
            self.currentSessionID = UUID()
            self.currentWindowID = 0
            return (s, session)
        }
        if let session {
            VTCompressionSessionInvalidate(session)
        }
        stopObservers()
        AppMirroringInputInjector.shared.showCursor()
        Task { try? await s?.stopCapture() }
    }
}

private extension NSLock {
    @discardableResult
    func withLockUnchecked<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }; return body()
    }
}
