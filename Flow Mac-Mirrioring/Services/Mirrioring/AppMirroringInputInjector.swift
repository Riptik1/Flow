//
//  AppMirroringInputInjector.swift
//  Flow
//
//  Created by Riptik Jhajhria on 07/06/26.
//

import CoreGraphics
import AppKit

final class AppMirroringInputInjector {
    static let shared = AppMirroringInputInjector()
    private let inputQueue = DispatchQueue(label: "flow.input", qos: .userInteractive)
    private var cursorHidden = false

    func hideCursor() {
        inputQueue.async {
            guard !self.cursorHidden else { return }
            CGDisplayHideCursor(CGMainDisplayID())
            self.cursorHidden = true
        }
    }

    func showCursor() {
        inputQueue.async {
            guard self.cursorHidden else { return }
            CGDisplayShowCursor(CGMainDisplayID())
            self.cursorHidden = false
        }
    }

    private func screenPoint(x: Float, y: Float, windowFrame: CGRect) -> CGPoint {
        CGPoint(
            x: windowFrame.origin.x + CGFloat(x) * windowFrame.width,
            y: windowFrame.origin.y + CGFloat(y) * windowFrame.height
        )
    }

    // MARK: - Click bookkeeping (only touched on inputQueue)

    private var lastClickAt: CFTimeInterval = 0
    private var lastClickPoint: CGPoint = .zero
    private var lastClickCount: Int64 = 0
    private var activeClickState: Int64 = 1
    private var scrollActive = false
    private var scrollEndWork: DispatchWorkItem?

    /// Two quick taps in (nearly) the same spot become a real double click on the Mac,
    /// so the phone can send every tap immediately instead of waiting to see if a second one follows.
    private func nextClickState(at pt: CGPoint) -> Int64 {
        let now = CACurrentMediaTime()
        let near = hypot(pt.x - lastClickPoint.x, pt.y - lastClickPoint.y) < 14
        let count: Int64 = (now - lastClickAt < 0.45 && near) ? min(lastClickCount + 1, 3) : 1
        lastClickAt = now
        lastClickPoint = pt
        lastClickCount = count
        return count
    }

    /// Moving the pointer first makes hover/tracking areas (browsers, Electron apps, menus) see the click location.
    private func move(to pt: CGPoint, src: CGEventSource) {
        CGEvent(mouseEventSource: src, mouseType: .mouseMoved, mouseCursorPosition: pt, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    private func mouse(_ type: CGEventType, _ pt: CGPoint, _ button: CGMouseButton, state: Int64, src: CGEventSource) {
        guard let e = CGEvent(mouseEventSource: src, mouseType: type, mouseCursorPosition: pt, mouseButton: button) else { return }
        e.setIntegerValueField(.mouseEventClickState, value: state)
        e.post(tap: .cghidEventTap)
    }

    func injectClick(x: Float, y: Float, windowFrame: CGRect) {
        guard windowFrame.width > 0, windowFrame.height > 0 else { return }
        let pt = screenPoint(x: x, y: y, windowFrame: windowFrame)
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            let state = self.nextClickState(at: pt)
            self.move(to: pt, src: src)
            self.mouse(.leftMouseDown, pt, .left, state: state, src: src)
            usleep(12_000)
            self.mouse(.leftMouseUp, pt, .left, state: state, src: src)
        }
    }

    func injectTouch(phase: Int, x: Float, y: Float, windowFrame: CGRect) {
        guard windowFrame.width > 0, windowFrame.height > 0 else { return }
        let pt = screenPoint(x: x, y: y, windowFrame: windowFrame)
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            switch phase {
            case 0:
                self.activeClickState = self.nextClickState(at: pt)
                self.move(to: pt, src: src)
                self.mouse(.leftMouseDown, pt, .left, state: self.activeClickState, src: src)
            case 1:
                self.mouse(.leftMouseDragged, pt, .left, state: self.activeClickState, src: src)
            default:
                self.mouse(.leftMouseUp, pt, .left, state: self.activeClickState, src: src)
            }
        }
    }

    func injectRightClick(x: Float, y: Float, windowFrame: CGRect) {
        guard windowFrame.width > 0, windowFrame.height > 0 else { return }
        let pt = screenPoint(x: x, y: y, windowFrame: windowFrame)
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            self.move(to: pt, src: src)
            self.mouse(.rightMouseDown, pt, .right, state: 1, src: src)
            usleep(30_000)
            self.mouse(.rightMouseUp, pt, .right, state: 1, src: src)
        }
    }

    func injectDoubleClick(x: Float, y: Float, windowFrame: CGRect) {
        guard windowFrame.width > 0, windowFrame.height > 0 else { return }
        let pt = screenPoint(x: x, y: y, windowFrame: windowFrame)
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            self.move(to: pt, src: src)
            for state in [Int64(1), 2] {
                self.mouse(.leftMouseDown, pt, .left, state: state, src: src)
                usleep(15_000)
                self.mouse(.leftMouseUp, pt, .left, state: state, src: src)
                usleep(15_000)
            }
            self.lastClickAt = CACurrentMediaTime()
            self.lastClickPoint = pt
            self.lastClickCount = 2
        }
    }

    /// Scroll deltas from one finger gesture are sent as one continuous scroll (began → changed → ended),
    /// like a real trackpad, instead of many separate gestures. That is what makes scrolling smooth.
    func injectScroll(deltaX: Float, deltaY: Float) {
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }

            let phase: Int64 = self.scrollActive ? 2 : 1
            self.scrollActive = true
            if let e = CGEvent(source: src) {
                e.type = .scrollWheel
                e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
                e.setIntegerValueField(.scrollWheelEventScrollPhase, value: phase)
                e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Double(deltaY))
                e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: Double(deltaX))
                e.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(deltaY.rounded()))
                e.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(deltaX.rounded()))
                e.post(tap: .cghidEventTap)
            }

            self.scrollEndWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self, let src = CGEventSource(stateID: .hidSystemState) else { return }
                self.scrollActive = false
                if let e = CGEvent(source: src) {
                    e.type = .scrollWheel
                    e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
                    e.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
                    e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
                    e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: 0)
                    e.post(tap: .cghidEventTap)
                }
            }
            self.scrollEndWork = work
            self.inputQueue.asyncAfter(deadline: .now() + 0.09, execute: work)
        }
    }

    func injectText(_ text: String) {
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            for scalar in text.unicodeScalars {
                var ch = UniChar(scalar.value & 0xFFFF)
                if let dn = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) {
                    dn.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
                    dn.post(tap: .cghidEventTap)
                }
                if let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false) {
                    up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &ch)
                    up.post(tap: .cghidEventTap)
                }
            }
        }
    }

    func injectKey(keyCode: Int, modifiers: Int, pressed: Bool) {
        let mapped = HIDToMacKeyCode.map(keyCode)
        var flags: CGEventFlags = []
        if modifiers & 1 != 0 { flags.insert(.maskCommand) }
        if modifiers & 2 != 0 { flags.insert(.maskShift) }
        if modifiers & 4 != 0 { flags.insert(.maskAlternate) }
        if modifiers & 8 != 0 { flags.insert(.maskControl) }
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            if let e = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(mapped), keyDown: pressed) {
                e.flags = flags
                e.post(tap: .cghidEventTap)
            }
        }
    }
}

struct HIDToMacKeyCode {
    static func map(_ hid: Int) -> Int {
        let table: [Int: Int] = [
            0x04: 0x00, 0x05: 0x0B, 0x06: 0x08, 0x07: 0x02, 0x08: 0x0E,
            0x09: 0x03, 0x0A: 0x05, 0x0B: 0x04, 0x0C: 0x22, 0x0D: 0x26,
            0x0E: 0x28, 0x0F: 0x25, 0x10: 0x2E, 0x11: 0x2D, 0x12: 0x1F,
            0x13: 0x23, 0x14: 0x0C, 0x15: 0x0F, 0x16: 0x01, 0x17: 0x11,
            0x18: 0x20, 0x19: 0x09, 0x1A: 0x0D, 0x1B: 0x07, 0x1C: 0x10,
            0x1D: 0x06, 0x1E: 0x12, 0x1F: 0x13, 0x20: 0x14, 0x21: 0x15,
            0x22: 0x17, 0x23: 0x16, 0x24: 0x1A, 0x25: 0x19, 0x26: 0x1C,
            0x27: 0x1D, 0x28: 0x24, 0x29: 0x35, 0x2A: 0x33, 0x2B: 0x30,
            0x2C: 0x31, 0x2D: 0x1B, 0x2E: 0x18, 0x2F: 0x21, 0x30: 0x1E,
            0x31: 0x2A, 0x33: 0x29, 0x34: 0x27, 0x35: 0x32, 0x36: 0x2B,
            0x37: 0x2F, 0x38: 0x2C, 0x39: 0x39, 0x3A: 0x7A, 0x3B: 0x78,
            0x3C: 0x63, 0x3D: 0x76, 0x3E: 0x60, 0x3F: 0x61, 0x40: 0x62,
            0x41: 0x64, 0x42: 0x65, 0x43: 0x6D, 0x44: 0x67, 0x45: 0x6F,
            0x49: 0x72, 0x4A: 0x73, 0x4B: 0x74, 0x4C: 0x75, 0x4D: 0x77,
            0x4E: 0x79, 0x4F: 0x7C, 0x50: 0x7B, 0x51: 0x7D, 0x52: 0x7E,
            0xE0: 0x3B, 0xE1: 0x38, 0xE2: 0x3A, 0xE3: 0x37, 0xE4: 0x3B,
            0xE5: 0x38, 0xE6: 0x3A, 0xE7: 0x37
        ]
        return table[hid] ?? hid
    }
}
