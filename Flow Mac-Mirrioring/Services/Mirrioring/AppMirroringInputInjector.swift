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

    func injectClick(x: Float, y: Float, windowFrame: CGRect) {
        guard windowFrame.width > 0, windowFrame.height > 0 else { return }
        let pt = screenPoint(x: x, y: y, windowFrame: windowFrame)
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            if let e = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: pt, mouseButton: .left) {
                e.setIntegerValueField(.mouseEventClickState, value: 1)
                e.post(tap: .cghidEventTap)
            }
            usleep(20_000)
            if let e = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: pt, mouseButton: .left) {
                e.setIntegerValueField(.mouseEventClickState, value: 1)
                e.post(tap: .cghidEventTap)
            }
        }
    }

    func injectTouch(phase: Int, x: Float, y: Float, windowFrame: CGRect) {
        guard windowFrame.width > 0, windowFrame.height > 0 else { return }
        let pt = screenPoint(x: x, y: y, windowFrame: windowFrame)
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            switch phase {
            case 0:
                if let e = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: pt, mouseButton: .left) {
                    e.setIntegerValueField(.mouseEventClickState, value: 1)
                    e.post(tap: .cghidEventTap)
                }
            case 1:
                CGEvent(mouseEventSource: src, mouseType: .leftMouseDragged, mouseCursorPosition: pt, mouseButton: .left)?.post(tap: .cghidEventTap)
            default:
                if let e = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: pt, mouseButton: .left) {
                    e.setIntegerValueField(.mouseEventClickState, value: 1)
                    e.post(tap: .cghidEventTap)
                }
            }
        }
    }

    func injectRightClick(x: Float, y: Float, windowFrame: CGRect) {
        guard windowFrame.width > 0, windowFrame.height > 0 else { return }
        let pt = screenPoint(x: x, y: y, windowFrame: windowFrame)
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            CGEvent(mouseEventSource: src, mouseType: .rightMouseDown, mouseCursorPosition: pt, mouseButton: .right)?.post(tap: .cghidEventTap)
            usleep(50_000)
            CGEvent(mouseEventSource: src, mouseType: .rightMouseUp, mouseCursorPosition: pt, mouseButton: .right)?.post(tap: .cghidEventTap)
        }
    }

    func injectDoubleClick(x: Float, y: Float, windowFrame: CGRect) {
        guard windowFrame.width > 0, windowFrame.height > 0 else { return }
        let pt = screenPoint(x: x, y: y, windowFrame: windowFrame)
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }
            if let e = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: pt, mouseButton: .left) {
                e.setIntegerValueField(.mouseEventClickState, value: 1)
                e.post(tap: .cghidEventTap)
            }
            usleep(30_000)
            if let e = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: pt, mouseButton: .left) {
                e.setIntegerValueField(.mouseEventClickState, value: 1)
                e.post(tap: .cghidEventTap)
            }
            usleep(30_000)
            if let e = CGEvent(mouseEventSource: src, mouseType: .leftMouseDown, mouseCursorPosition: pt, mouseButton: .left) {
                e.setIntegerValueField(.mouseEventClickState, value: 2)
                e.post(tap: .cghidEventTap)
            }
            usleep(30_000)
            if let e = CGEvent(mouseEventSource: src, mouseType: .leftMouseUp, mouseCursorPosition: pt, mouseButton: .left) {
                e.setIntegerValueField(.mouseEventClickState, value: 2)
                e.post(tap: .cghidEventTap)
            }
        }
    }

    func injectScroll(deltaX: Float, deltaY: Float) {
        inputQueue.async {
            guard let src = CGEventSource(stateID: .hidSystemState) else { return }

            if let e = CGEvent(source: src) {
                e.type = .scrollWheel
                e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
                e.setIntegerValueField(.scrollWheelEventScrollPhase, value: 1)
                e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: Double(deltaY))
                e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: Double(deltaX))
                e.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(deltaY.rounded()))
                e.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(deltaX.rounded()))
                e.post(tap: .cghidEventTap)
            }

            if let e = CGEvent(source: src) {
                e.type = .scrollWheel
                e.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
                e.setIntegerValueField(.scrollWheelEventScrollPhase, value: 4)
                e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: 0)
                e.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: 0)
                e.post(tap: .cghidEventTap)
            }
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
