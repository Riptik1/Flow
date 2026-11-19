//
//  AppMirroringViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import SwiftUI
import UIKit

final class AppMirroringViewModel: ObservableObject {
    @Published var isSessionActive = false
    @Published var statusText = "Starting..."
    @Published var errorMessage: String?
    @Published var hasReceivedFrame = false
    @Published var showKeyboard = false
    @Published var captureAspect: CGFloat = 16.0 / 9.0
    @Published var selectionMenuLocation: CGPoint?
    @Published var shareText: String?
    /// Mac screen brightness, 0 (dark – nobody nearby can tell it's on) ... 1 (full).
    @Published var macBrightness: Double = 1

    private var hasStartedStream = false

    private(set) var renderer = FrameRenderer()

    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()
    private var timeoutTask: Task<Void, Never>?
    private var awaitingClipboardForShare = false
    private var brightnessBeforeChange: Double?
    private var brightnessWasChanged = false
    private var lastBrightnessSentAt = Date.distantPast
    private var pendingBrightnessSend: DispatchWorkItem?

    init(connectionService: FlowConnectionServicing = LiveFlowConnectionService.shared) {
        self.connectionService = connectionService
        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] msg in self?.handleMessage(msg) }
            .store(in: &cancellables)
    }

    func startMirroring(bundleID: String) {
        isSessionActive = true
        beginSession(bundleID: bundleID)
    }

    func switchApp(to bundleID: String) {
        beginSession(bundleID: bundleID)
    }

    private func beginSession(bundleID: String) {
        statusText = "Launching app..."
        errorMessage = nil
        hasReceivedFrame = false
        hasStartedStream = false
        captureAspect = 16.0 / 9.0
        renderer.reset()
        connectionService.send(.startAppMirroring(bundleID: bundleID))
        scheduleTimeout()
    }

    private func scheduleTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard let self, !Task.isCancelled, !self.hasReceivedFrame else { return }
            if !self.hasStartedStream {
                self.statusText = "Launching app on your Mac..."
            }
            try? await Task.sleep(nanoseconds: 24_000_000_000)
            guard !Task.isCancelled, !self.hasReceivedFrame else { return }
            self.statusText = self.hasStartedStream
                ? "Waiting for video from your Mac..."
                : "Still working, this can take longer on a slow connection..."
            try? await Task.sleep(nanoseconds: 25_000_000_000)
            guard !Task.isCancelled, !self.hasReceivedFrame else { return }
            self.errorMessage = "Connection timed out. Check your internet connection and try again."
        }
    }

    func stopMirroring() {
        restoreBrightnessIfNeeded()
        timeoutTask?.cancel(); timeoutTask = nil
        connectionService.send(.stopAppMirroring)
        isSessionActive = false
        hasReceivedFrame = false
        hasStartedStream = false
    }

    private func normalizedCoords(location: CGPoint, viewSize: CGSize) -> (Float, Float)? {
        guard viewSize.width > 0, viewSize.height > 0 else { return nil }
        let viewAspect = viewSize.width / viewSize.height
        var imageW = viewSize.width, imageH = viewSize.height
        var offsetX: CGFloat = 0, offsetY: CGFloat = 0
        if viewAspect > captureAspect {
            imageW = viewSize.height * captureAspect
            offsetX = (viewSize.width - imageW) / 2
        } else {
            imageH = viewSize.width / captureAspect
            offsetY = (viewSize.height - imageH) / 2
        }
        guard imageW > 0, imageH > 0 else { return nil }
        let margin: CGFloat = 6
        let lx = location.x - offsetX
        let ly = location.y - offsetY
        guard lx >= -margin, lx <= imageW + margin, ly >= -margin, ly <= imageH + margin else { return nil }
        let clampedX = min(max(lx, 0), imageW)
        let clampedY = min(max(ly, 0), imageH)
        return (Float(clampedX / imageW), Float(clampedY / imageH))
    }

    func sendTap(location: CGPoint, viewSize: CGSize) {
        guard let (x, y) = normalizedCoords(location: location, viewSize: viewSize) else { return }
        connectionService.send(.appMirroringInputClick(x: x, y: y))
    }

    func sendDoubleTap(location: CGPoint, viewSize: CGSize) {
        guard let (x, y) = normalizedCoords(location: location, viewSize: viewSize) else { return }
        connectionService.send(.appMirroringInputDoubleClick(x: x, y: y))
    }

    func sendRightClick(location: CGPoint, viewSize: CGSize) {
        guard let (x, y) = normalizedCoords(location: location, viewSize: viewSize) else { return }
        connectionService.send(.appMirroringInputRightClick(x: x, y: y))
    }

    func sendTouch(phase: Int, location: CGPoint, viewSize: CGSize) {
        guard let (x, y) = normalizedCoords(location: location, viewSize: viewSize) else { return }
        connectionService.send(.appMirroringInputTouch(phase: phase, x: x, y: y))
    }

    func sendScroll(deltaX: CGFloat, deltaY: CGFloat) {
        connectionService.send(.appMirroringInputScroll(dx: Float(deltaX), dy: Float(deltaY)))
    }

    // MARK: - Privacy brightness

    func requestBrightness() {
        connectionService.send(.requestDisplayBrightness)
    }

    /// Called continuously while the slider moves; sends are spaced out so the Mac and the link keep up,
    /// and the final value is always delivered.
    func setBrightness(_ value: Double) {
        let level = min(1, max(0, value))
        macBrightness = level
        brightnessWasChanged = true
        let interval = 0.05
        let elapsed = Date().timeIntervalSince(lastBrightnessSentAt)
        if elapsed >= interval {
            flushBrightness()
        } else if pendingBrightnessSend == nil {
            let work = DispatchWorkItem { [weak self] in self?.flushBrightness() }
            pendingBrightnessSend = work
            DispatchQueue.main.asyncAfter(deadline: .now() + (interval - elapsed), execute: work)
        }
    }

    /// Sends the latest value now and asks the Mac what it really applied (so the UI never lies).
    func commitBrightness() {
        flushBrightness()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.connectionService.send(.requestDisplayBrightness)
        }
    }

    private func flushBrightness() {
        pendingBrightnessSend?.cancel()
        pendingBrightnessSend = nil
        lastBrightnessSentAt = Date()
        connectionService.send(.setDisplayBrightness(level: Float(macBrightness)))
    }

    /// Leaving mirroring puts the Mac's screen back, so it isn't left dark by accident.
    private func restoreBrightnessIfNeeded() {
        pendingBrightnessSend?.cancel()
        pendingBrightnessSend = nil
        guard brightnessWasChanged else { return }
        brightnessWasChanged = false
        let original = brightnessBeforeChange ?? 1
        macBrightness = original
        connectionService.send(.setDisplayBrightness(level: Float(original)))
    }

    func copySelection() {
        selectionMenuLocation = nil
        sendShortcut(hidKeyCode: 0x06)
    }

    func cutSelection() {
        selectionMenuLocation = nil
        sendShortcut(hidKeyCode: 0x1B)
    }

    func shareSelection() {
        selectionMenuLocation = nil
        awaitingClipboardForShare = true
        sendShortcut(hidKeyCode: 0x06)
    }

    private func sendShortcut(hidKeyCode: Int) {
        connectionService.send(.appMirroringInputKey(keyCode: hidKeyCode, modifiers: 1, pressed: true))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.connectionService.send(.appMirroringInputKey(keyCode: hidKeyCode, modifiers: 1, pressed: false))
        }
    }

    func sendKey(keyCode: Int, modifiers: UIKeyModifierFlags, pressed: Bool) {
        var mod = 0
        if modifiers.contains(.command)   { mod |= 1 }
        if modifiers.contains(.shift)     { mod |= 2 }
        if modifiers.contains(.alternate) { mod |= 4 }
        if modifiers.contains(.control)   { mod |= 8 }
        connectionService.send(.appMirroringInputKey(keyCode: keyCode, modifiers: mod, pressed: pressed))
    }

    func sendText(_ text: String) {
        connectionService.send(.appMirroringInputText(text: text))
    }

    private func handleMessage(_ message: FlowMessage) {
        switch message {
        case .appMirroringConfig(let width, let height, _, _, _):
            hasStartedStream = true
            captureAspect = width > 0 && height > 0 ? CGFloat(width) / CGFloat(height) : 16.0 / 9.0
            statusText = "Stream starting..."

        case .appMirroringStarted:
            hasStartedStream = true
            statusText = "Receiving frames..."

        case .appMirroringFrame(let data, _):
            guard !data.isEmpty else { return }
            renderer.display(data)
            if !hasReceivedFrame {
                hasReceivedFrame = true
                timeoutTask?.cancel()
                timeoutTask = nil
            }
            if errorMessage != nil {
                errorMessage = nil
            }

        case .appMirroringError(let error):
            timeoutTask?.cancel(); timeoutTask = nil
            errorMessage = error

        case .appMirroringStopped:
            isSessionActive = false
            hasReceivedFrame = false

        case .displayBrightness(let level):
            let value = Double(min(1, max(0, level)))
            if !brightnessWasChanged || brightnessBeforeChange == nil {
                // Remember what the Mac was at before we touched it (never "restore" to a dark screen).
                if brightnessBeforeChange == nil { brightnessBeforeChange = value < 0.1 ? 0.7 : value }
            }
            // Don't fight the slider while the user is dragging it.
            if pendingBrightnessSend == nil, Date().timeIntervalSince(lastBrightnessSentAt) > 0.2 {
                macBrightness = value
            }

        case .clipboardDidChange(let item):
            guard awaitingClipboardForShare else { return }
            awaitingClipboardForShare = false
            if let text = item.text, !text.isEmpty {
                shareText = text
            }

        default:
            break
        }
    }
}
