//
//  RemoteAppMirroringHost.swift
//  Flow
//
//  Created by Riptik Jhajhria on 18/07/26.
//

#if canImport(AppKit)
import AppKit
import ApplicationServices
import CoreMedia
import Foundation
import ScreenCaptureKit
import VideoToolbox

final class RemoteAppMirroringHost: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    static let shared = RemoteAppMirroringHost()

    private let lock = NSLock()
    private nonisolated(unsafe) var stream: SCStream?
    private nonisolated(unsafe) var isRunning = false
    private nonisolated(unsafe) var targetWindowFrame: CGRect = .zero
    private nonisolated(unsafe) var currentWindowID: CGWindowID = 0
    private nonisolated(unsafe) var currentSessionID = UUID()
    private nonisolated(unsafe) var compressionSession: VTCompressionSession?
    private nonisolated(unsafe) var replyBlock: ((FlowMessage) -> Void)?
    private nonisolated(unsafe) var currentCapW: Int = 0
    private nonisolated(unsafe) var currentCapH: Int = 0
    private nonisolated(unsafe) var lastEncodedAt: CFTimeInterval = 0
    private nonisolated(unsafe) var lastAppliedBitRate: Int32 = 0
    private nonisolated(unsafe) var lastRawWindowSize: CGSize = .zero
    private nonisolated(unsafe) var trackingBusy = false

    private var frameTimer: Timer?
    private let encodeSemaphore = DispatchSemaphore(value: 2)

    private let targetFrameRate: Int = 20
    private var minFrameInterval: CFTimeInterval { 1.0 / Double(targetFrameRate) }
    private let averageBitRate: Int = 2_500_000
    private let maxCaptureWidth: Int = 1280

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

        default:
            break
        }
    }

    private func lockedValue<T>(_ body: () -> T) -> T {
        lock.lock(); defer { lock.unlock() }; return body()
    }

    private static var hasPromptedAccessibility = false

    private static func ensureAccessibilityPermission() {
        let trusted = AXIsProcessTrusted()
        flowLog("[Flow][RemoteHost] Accessibility permission check: trusted=\(trusted)")
        guard !trusted, !hasPromptedAccessibility else { return }
        hasPromptedAccessibility = true
        let options: [String: Any] = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let promptedTrusted = AXIsProcessTrustedWithOptions(options as CFDictionary)
        flowLog("[Flow][RemoteHost] Accessibility permission prompt shown, trusted=\(promptedTrusted). If this stays false, grant access in System Settings > Privacy & Security > Accessibility for this app, then quit and relaunch it.")
    }

    private func startMirroring(bundleID: String, reply: @escaping (FlowMessage) -> Void) {
        Self.ensureAccessibilityPermission()
        let sessionID = UUID()
        let (previousStream, previousSession) = lockedValue { () -> (SCStream?, VTCompressionSession?) in
            let s = stream
            let c = compressionSession
            stream = nil
            compressionSession = nil
            isRunning = false
            replyBlock = nil
            lastEncodedAt = 0
            currentSessionID = sessionID
            currentWindowID = 0
            targetWindowFrame = .zero
            lastRawWindowSize = .zero
            return (s, c)
        }
        if let previousSession {
            VTCompressionSessionInvalidate(previousSession)
        }
        frameTimer?.invalidate()
        frameTimer = nil
        RemoteFrameTransport.shared.beginNewSession()

        flowLog("[Flow][RemoteHost] startMirroring: bundleID=\(bundleID) sessionID=\(sessionID)")

        Task {
            if let previousStream {
                try? await previousStream.stopCapture()
                try? await Task.sleep(nanoseconds: 350_000_000)
            }

            let launched = await Self.ensureAppRunning(bundleID: bundleID)

            guard lockedValue({ currentSessionID == sessionID }) else {
                flowLog("[Flow][RemoteHost] session superseded before window lookup")
                return
            }

            guard launched else {
                flowLog("[Flow][RemoteHost] ensureAppRunning FAILED for bundleID=\(bundleID)")
                reply(.appMirroringError(error: "Couldn't open this app. Make sure it's installed on your Mac and try again."))
                return
            }

            flowLog("[Flow][RemoteHost] looking up window for bundleID=\(bundleID)")
            var window = await Self.quickWindowLookup(bundleID: bundleID)

            if window == nil {
                flowLog("[Flow][RemoteHost] no window found yet, reopening bundleID=\(bundleID)")
                guard lockedValue({ currentSessionID == sessionID }) else {
                    flowLog("[Flow][RemoteHost] session superseded before reopen attempt")
                    return
                }
                _ = await Self.reopenApplication(bundleID: bundleID)
                window = try? await findBestWindow(bundleID: bundleID)
            }

            guard let foundWindow = window else {
                flowLog("[Flow][RemoteHost] findBestWindow found nothing for bundleID=\(bundleID)")
                reply(.appMirroringError(error: "Could not find a window for this app."))
                return
            }
            var resolvedWindow = foundWindow
            flowLog("[Flow][RemoteHost] found window id=\(resolvedWindow.windowID) frame=\(resolvedWindow.frame)")

            guard lockedValue({ currentSessionID == sessionID }) else {
                flowLog("[Flow][RemoteHost] session superseded after window lookup")
                return
            }

            resolvedWindow = await Self.waitForStableFrame(bundleID: bundleID, initial: resolvedWindow)
            flowLog("[Flow][RemoteHost] stabilized window frame=\(resolvedWindow.frame)")

            guard lockedValue({ currentSessionID == sessionID }) else {
                flowLog("[Flow][RemoteHost] session superseded after stabilizing frame")
                return
            }

            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                app.activate(options: [.activateAllWindows])
            }

            let inputFrame = Self.refinedInputFrame(for: resolvedWindow)
            flowLog("[Flow][RemoteHost] input frame resolved=\(inputFrame) rawFrame=\(resolvedWindow.frame)")

            lockedValue {
                targetWindowFrame = inputFrame
                currentWindowID = resolvedWindow.windowID
                lastRawWindowSize = resolvedWindow.frame.size
                replyBlock = reply
            }

            startWindowTracking(bundleID: bundleID, sessionID: sessionID)
            await buildStream(window: resolvedWindow, captureFrame: inputFrame, bundleID: bundleID, sessionID: sessionID, reply: reply)
        }
    }

    private static func reopenApplication(bundleID: String) async -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return false }
        do {
            try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } catch {
            flowLog("[Flow][RemoteHost] reopenApplication: openApplication FAILED error=\(error)")
        }
        if let app = await waitForRunningApplication(bundleID: bundleID, timeout: 6.0) {
            app.activate(options: [.activateAllWindows])
            Task.detached(priority: .utility) { await deminiaturizeWindows(for: app) }
            return true
        }
        return false
    }

    private static func ensureAppRunning(bundleID: String) async -> Bool {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
            flowLog("[Flow][RemoteHost] ensureAppRunning: already running bundleID=\(bundleID) isHidden=\(app.isHidden)")
            if app.isHidden {
                app.unhide()
            }
            app.activate(options: [.activateAllWindows])
            Task.detached(priority: .utility) { await deminiaturizeWindows(for: app) }
            return true
        }

        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            flowLog("[Flow][RemoteHost] ensureAppRunning: no application URL found for bundleID=\(bundleID)")
            return false
        }

        for attempt in 1...2 {
            flowLog("[Flow][RemoteHost] ensureAppRunning: launching bundleID=\(bundleID) attempt=\(attempt) url=\(url)")
            do {
                try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
            } catch {
                flowLog("[Flow][RemoteHost] ensureAppRunning: openApplication FAILED attempt=\(attempt) error=\(error)")
            }

            if let app = await waitForRunningApplication(bundleID: bundleID, timeout: 10.0) {
                flowLog("[Flow][RemoteHost] ensureAppRunning: confirmed running bundleID=\(bundleID) attempt=\(attempt)")
                app.activate(options: [.activateAllWindows])
                Task.detached(priority: .utility) { await deminiaturizeWindows(for: app) }
                return true
            }
            flowLog("[Flow][RemoteHost] ensureAppRunning: not running yet after attempt=\(attempt), will retry")
        }
        return false
    }

    private static func waitForRunningApplication(bundleID: String, timeout: Double) async -> NSRunningApplication? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                return app
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID })
    }

    private static func waitForStableFrame(bundleID: String, initial: SCWindow) async -> SCWindow {
        var current = initial
        for _ in 0..<6 {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
                  let latest = Self.selectBestWindow(from: content.windows, bundleID: bundleID, requireOnScreen: false) else { break }
            if latest.frame == current.frame {
                return latest
            }
            current = latest
        }
        return current
    }

    private static func visibleFrame(_ frame: CGRect, displays: [SCDisplay]) -> CGRect {
        guard let display = displayContaining(frame, in: displays) else { return frame }
        let visible = frame.intersection(display.frame)
        guard !visible.isNull, visible.width >= 2, visible.height >= 2 else { return frame }
        return visible
    }

    private static func displayContaining(_ rect: CGRect, in displays: [SCDisplay]) -> SCDisplay? {
        displays.max(by: {
            $0.frame.intersection(rect).width * $0.frame.intersection(rect).height <
            $1.frame.intersection(rect).width * $1.frame.intersection(rect).height
        })
    }

    private func buildStream(window: SCWindow, captureFrame: CGRect, bundleID: String, sessionID: UUID, reply: @escaping (FlowMessage) -> Void) async {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
              let display = Self.displayContaining(captureFrame, in: content.displays) else {
            flowLog("[Flow][RemoteHost] buildStream: could not locate display for this window")
            reply(.appMirroringError(error: "Could not locate the display for this window."))
            return
        }

        // Capture and click mapping must use the same on-screen rectangle.
        let frame = Self.visibleFrame(captureFrame, displays: content.displays)
        lockedValue { targetWindowFrame = frame }

        let rawW = max(Int(frame.width), 2)
        let rawH = max(Int(frame.height), 2)
        let aspect = Double(rawW) / Double(rawH)
        var capW = min(rawW, maxCaptureWidth)
        var capH = max(2, Int(Double(capW) / aspect))
        capW = (capW / 2) * 2
        capH = (capH / 2) * 2

        flowLog("[Flow][RemoteHost] buildStream: windowFrame=\(frame) capW=\(capW) capH=\(capH)")

        guard let newSession = Self.makeCompressionSession(width: Int32(capW), height: Int32(capH), frameRate: targetFrameRate, bitRate: averageBitRate) else {
            flowLog("[Flow][RemoteHost] buildStream: makeCompressionSession FAILED")
            reply(.appMirroringError(error: "Could not create the video encoder."))
            return
        }

        let rawSourceRect = CGRect(
            x: frame.origin.x - display.frame.origin.x,
            y: frame.origin.y - display.frame.origin.y,
            width: frame.width,
            height: frame.height
        )
        let displayBounds = CGRect(origin: .zero, size: display.frame.size)
        let sourceRect = rawSourceRect.intersection(displayBounds)

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
                label: "flow.remote.capture.\(sessionID.uuidString.prefix(8))",
                qos: .userInteractive
            )
            let newStream = SCStream(filter: filter, configuration: config, delegate: self)
            try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
            flowLog("[Flow][RemoteHost] buildStream: starting capture")
            try await newStream.startCapture()
            flowLog("[Flow][RemoteHost] buildStream: capture started")

            guard lockedValue({ currentSessionID == sessionID }) else {
                flowLog("[Flow][RemoteHost] buildStream: session superseded after startCapture, stopping")
                try? await newStream.stopCapture()
                VTCompressionSessionInvalidate(newSession)
                return
            }

            let oldSession = lockedValue { () -> VTCompressionSession? in
                let old = compressionSession
                stream = newStream
                compressionSession = newSession
                isRunning = true
                lastEncodedAt = 0
                currentCapW = capW
                currentCapH = capH
                lastAppliedBitRate = 0
                return old
            }
            if let oldSession {
                VTCompressionSessionInvalidate(oldSession)
            }

            reply(.appMirroringConfig(width: capW, height: capH, frameRate: targetFrameRate, port: 0, host: ""))
            reply(.appMirroringStarted)
            AppMirroringInputInjector.shared.hideCursor()
        } catch {
            flowLog("[Flow][RemoteHost] buildStream FAILED error=\(error)")
            VTCompressionSessionInvalidate(newSession)
            reply(.appMirroringError(error: error.localizedDescription))
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid, let pixelBuffer = sampleBuffer.imageBuffer else { return }

        lock.lock()
        guard isRunning, let session = compressionSession else { lock.unlock(); return }
        let now = CACurrentMediaTime()
        let elapsed = now - lastEncodedAt
        guard elapsed >= minFrameInterval else { lock.unlock(); return }
        guard replyBlock != nil else { lock.unlock(); return }
        guard RemoteFrameTransport.shared.reserveSlot() else { lock.unlock(); return }
        lastEncodedAt = now
        let bitRate = RemoteFrameTransport.shared.currentBitRate()
        if bitRate != lastAppliedBitRate {
            VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: bitRate as CFNumber)
            lastAppliedBitRate = bitRate
        }
        lock.unlock()

        guard encodeSemaphore.wait(timeout: .now()) == .success else {
            RemoteFrameTransport.shared.releaseSlot()
            return
        }

        let forceKeyframe = RemoteFrameTransport.shared.consumeForceKeyframe()
        let frameProperties: CFDictionary? = forceKeyframe
            ? [kVTEncodeFrameOptionKey_ForceKeyFrame as String: true] as CFDictionary
            : nil

        let pts = CMTime(seconds: now, preferredTimescale: 1_000_000)
        let status = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: pts,
            duration: .invalid,
            frameProperties: frameProperties,
            infoFlagsOut: nil
        ) { [weak self] encodeStatus, _, encodedSampleBuffer in
            defer { self?.encodeSemaphore.signal() }
            guard encodeStatus == noErr,
                  let encodedSampleBuffer,
                  CMSampleBufferDataIsReady(encodedSampleBuffer),
                  let annexB = Self.annexBData(from: encodedSampleBuffer) else {
                RemoteFrameTransport.shared.releaseSlot()
                return
            }
            RemoteFrameTransport.shared.sendReservedFrame(.appMirroringFrame(data: annexB, timestamp: now))
        }
        if status != noErr {
            encodeSemaphore.signal()
            RemoteFrameTransport.shared.releaseSlot()
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        flowLog("[Flow][RemoteHost] stream didStopWithError error=\(error)")
        lockedValue { isRunning = false }
        AppMirroringInputInjector.shared.showCursor()
    }

    private static func deminiaturizeWindows(for app: NSRunningApplication) {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else {
            flowLog("[Flow][RemoteHost] deminiaturizeWindows: could not read AX windows for bundleID=\(app.bundleIdentifier ?? "?")")
            return
        }
        for window in windows {
            var minimizedValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
                  let isMinimized = minimizedValue as? Bool, isMinimized else { continue }
            flowLog("[Flow][RemoteHost] deminiaturizeWindows: restoring a minimized window for bundleID=\(app.bundleIdentifier ?? "?")")
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
    }

    private static func quickWindowLookup(bundleID: String) async -> SCWindow? {
        for attempt in 0..<4 {
            if let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
               let best = selectBestWindow(from: content.windows, bundleID: bundleID, requireOnScreen: true) {
                return best
            }
            if attempt < 3 {
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
        return nil
    }

    private static func refinedInputFrame(for window: SCWindow) -> CGRect {
        let fallback = window.frame
        guard let pid = window.owningApplication?.processID else { return fallback }
        let axApp = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let axResult = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
        guard axResult == .success, let axWindows = windowsRef as? [AXUIElement], !axWindows.isEmpty else {
            flowLog("[Flow][RemoteHost] refinedInputFrame: AX windows lookup FAILED result=\(axResult.rawValue) trusted=\(AXIsProcessTrusted()) pid=\(pid), falling back to rawFrame=\(fallback)")
            return fallback
        }

        var bestFrame: CGRect?
        var bestDistance = CGFloat.greatestFiniteMagnitude

        for axWindow in axWindows {
            var positionRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            guard AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionRef) == .success,
                  AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeRef) == .success,
                  let positionValue = positionRef, CFGetTypeID(positionValue) == AXValueGetTypeID(),
                  let sizeValue = sizeRef, CFGetTypeID(sizeValue) == AXValueGetTypeID() else { continue }

            var position = CGPoint.zero
            var size = CGSize.zero
            guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
                  AXValueGetValue(sizeValue as! AXValue, .cgSize, &size) else { continue }

            let candidate = CGRect(origin: position, size: size)

            let identityDistance = abs(candidate.origin.x - fallback.origin.x)
                + abs(candidate.width - fallback.width)
            guard identityDistance <= 40 else { continue }

            let distance = identityDistance
                + abs(candidate.origin.y - fallback.origin.y)
                + abs(candidate.height - fallback.height)

            if distance < bestDistance {
                bestDistance = distance
                bestFrame = candidate
            }
        }

        let resolved = bestFrame ?? fallback
        flowLog("[Flow][RemoteHost] refinedInputFrame: rawFrame=\(fallback) resolved=\(resolved) matchedAX=\(bestFrame != nil)")
        return resolved
    }

    private func findBestWindow(bundleID: String) async throws -> SCWindow? {
        for attempt in 0..<20 {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            if let best = Self.selectBestWindow(from: content.windows, bundleID: bundleID, requireOnScreen: true) {
                return best
            }
            if attempt < 19 { try await Task.sleep(nanoseconds: 750_000_000) }
        }
        flowLog("[Flow][RemoteHost] findBestWindow: no on-screen window found for bundleID=\(bundleID), falling back to any window")
        if let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
           let fallback = Self.selectBestWindow(from: content.windows, bundleID: bundleID, requireOnScreen: false) {
            return fallback
        }
        return nil
    }

    private static func selectBestWindow(from windows: [SCWindow], bundleID: String, requireOnScreen: Bool = true) -> SCWindow? {
        let candidates = windows.filter {
            $0.owningApplication?.bundleIdentifier == bundleID
                && (!requireOnScreen || $0.isOnScreen)
                && $0.frame.width >= 100
                && $0.frame.height >= 100
        }
        let titled = candidates.filter { !($0.title?.isEmpty ?? true) }
        let pool = titled.isEmpty ? candidates : titled
        return pool.max(by: { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height })
    }

    private static func makeCompressionSession(width: Int32, height: Int32, frameRate: Int, bitRate: Int) -> VTCompressionSession? {
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
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_AverageBitRate, value: Int32(bitRate) as CFNumber)
        VTSessionSetProperty(session, key: kVTCompressionPropertyKey_ExpectedFrameRate, value: Int32(frameRate) as CFNumber)
        VTCompressionSessionPrepareToEncodeFrames(session)
        return session
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

    private func startWindowTracking(bundleID: String, sessionID: UUID) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.frameTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                guard let self else { return }
                let shouldRun = self.lockedValue { () -> Bool in
                    guard self.isRunning, self.currentSessionID == sessionID, !self.trackingBusy else { return false }
                    self.trackingBusy = true
                    return true
                }
                guard shouldRun else { return }
                Task {
                    defer { self.lockedValue { self.trackingBusy = false } }
                    guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false) else { return }
                    guard var best = await Self.selectBestWindow(from: content.windows, bundleID: bundleID) else { return }
                    guard await self.lockedValue({ self.isRunning && self.currentSessionID == sessionID }) else { return }

                    let previousSize = await self.lockedValue { self.lastRawWindowSize }
                    let widthDelta = abs(previousSize.width - best.frame.width)
                    let heightDelta = abs(previousSize.height - best.frame.height)
                    let isResizing = previousSize.width > 0 && previousSize.height > 0 && (widthDelta > 8 || heightDelta > 8)

                    let previousOrigin = await self.lockedValue { self.targetWindowFrame.origin }
                    let bestOrigin = Self.visibleFrame(best.frame, displays: content.displays).origin
                    let originDelta = max(abs(previousOrigin.x - bestOrigin.x), abs(previousOrigin.y - bestOrigin.y))
                    let hasMoved = originDelta > 2

                    if isResizing {
                        best = await Self.waitForStableFrame(bundleID: bundleID, initial: best)
                        guard await self.lockedValue({ self.isRunning && self.currentSessionID == sessionID }) else { return }
                    }

                    let refined = Self.visibleFrame(Self.refinedInputFrame(for: best), displays: content.displays)
                    await self.lockedValue {
                        self.targetWindowFrame = refined
                        self.currentWindowID = best.windowID
                        self.lastRawWindowSize = best.frame.size
                    }

                    guard isResizing || hasMoved else { return }
                    await self.reconfigureStream(for: refined, bundleID: bundleID, sessionID: sessionID)
                }
            }
        }
    }

    private func reconfigureStream(for windowFrame: CGRect, bundleID: String, sessionID: UUID) async {
        guard lockedValue({ currentSessionID == sessionID && isRunning }), let activeStream = lockedValue({ stream }) else { return }

        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
              let display = Self.displayContaining(windowFrame, in: content.displays) else {
            flowLog("[Flow][RemoteHost] reconfigureStream: could not locate display, skipping update")
            return
        }

        let rawSourceRect = CGRect(
            x: windowFrame.origin.x - display.frame.origin.x,
            y: windowFrame.origin.y - display.frame.origin.y,
            width: windowFrame.width,
            height: windowFrame.height
        )
        let displayBounds = CGRect(origin: .zero, size: display.frame.size)
        let sourceRect = rawSourceRect.intersection(displayBounds)

        let rawW = max(Int(windowFrame.width), 2)
        let rawH = max(Int(windowFrame.height), 2)
        let aspect = Double(rawW) / Double(rawH)
        var capW = min(rawW, maxCaptureWidth)
        var capH = max(2, Int(Double(capW) / aspect))
        capW = (capW / 2) * 2
        capH = (capH / 2) * 2

        let dimensionsChanged = capW != currentCapW || capH != currentCapH
        let (targetCapW, targetCapH) = dimensionsChanged ? (capW, capH) : (currentCapW, currentCapH)

        flowLog("[Flow][RemoteHost] reconfigureStream: updating sourceRect=\(sourceRect) dimensionsChanged=\(dimensionsChanged) capW=\(targetCapW) capH=\(targetCapH)")

        let newConfig = SCStreamConfiguration()
        newConfig.width = targetCapW
        newConfig.height = targetCapH
        newConfig.sourceRect = sourceRect
        newConfig.minimumFrameInterval = CMTime(value: 1, timescale: Int32(targetFrameRate))
        newConfig.queueDepth = 3
        newConfig.scalesToFit = true
        newConfig.showsCursor = false
        newConfig.pixelFormat = kCVPixelFormatType_32BGRA

        do {
            try await activeStream.updateConfiguration(newConfig)
        } catch {
            flowLog("[Flow][RemoteHost] reconfigureStream: updateConfiguration FAILED error=\(error)")
            return
        }

        guard dimensionsChanged else { return }
        guard lockedValue({ currentSessionID == sessionID && isRunning }) else { return }

        let bitRate = Int(RemoteFrameTransport.shared.currentBitRate())
        guard let newSession = Self.makeCompressionSession(width: Int32(capW), height: Int32(capH), frameRate: targetFrameRate, bitRate: bitRate) else {
            flowLog("[Flow][RemoteHost] reconfigureStream: makeCompressionSession FAILED")
            return
        }

        let oldSession = lockedValue { () -> VTCompressionSession? in
            guard currentSessionID == sessionID else { return nil }
            let old = compressionSession
            compressionSession = newSession
            currentCapW = capW
            currentCapH = capH
            lastAppliedBitRate = 0
            return old
        }
        if let oldSession {
            VTCompressionSessionInvalidate(oldSession)
        }

        let currentReply = lockedValue { replyBlock }
        currentReply?(.appMirroringConfig(width: capW, height: capH, frameRate: targetFrameRate, port: 0, host: ""))
    }

    private func stopMirroring() {
        let (existingStream, existingSession) = lockedValue { () -> (SCStream?, VTCompressionSession?) in
            let s = stream
            let c = compressionSession
            stream = nil
            compressionSession = nil
            isRunning = false
            targetWindowFrame = .zero
            currentWindowID = 0
            currentSessionID = UUID()
            replyBlock = nil
            lastEncodedAt = 0
            lastRawWindowSize = .zero
            return (s, c)
        }
        frameTimer?.invalidate()
        frameTimer = nil
        AppMirroringInputInjector.shared.showCursor()
        if let existingSession {
            VTCompressionSessionInvalidate(existingSession)
        }
        flowLog("[Flow][RemoteHost] stopMirroring")
        Task { try? await existingStream?.stopCapture() }
    }
}
#endif
