//
//  KeyboardService.swift
//  Flow
//
//  Created by Riptik Jhajhria on 27/05/26.
//

#if canImport(AppKit)
import AppKit
import CoreGraphics

final class KeyboardService {
    static let shared = KeyboardService()

    private let src: CGEventSource?
    private let queue = DispatchQueue(label: "com.flow.keyboard", qos: .userInteractive)

    private init() {
        src = CGEventSource(stateID: .hidSystemState)
    }

    func handle(_ message: FlowMessage) {
        queue.async { [weak self] in self?.process(message) }
    }

    private func process(_ message: FlowMessage) {
        switch message {
        case .keyPress(let keyCode, let modifiers):
            guard keyCode >= 0, keyCode <= Int(CGKeyCode.max) else { return }
            postKeyWithModifiers(CGKeyCode(keyCode), CGEventFlags(rawValue: UInt64(bitPattern: Int64(modifiers))))
        default:
            break
        }
    }

    private func postKeyWithModifiers(_ code: CGKeyCode, _ flags: CGEventFlags) {
        let modPairs: [(CGKeyCode, CGEventFlags)] = [
            (55, .maskCommand),
            (56, .maskShift),
            (58, .maskAlternate),
            (59, .maskControl),
        ]

        let needed = modPairs.filter { flags.contains($0.1) }

        var accumulated = CGEventFlags()
        for (vk, mask) in needed {
            accumulated.insert(mask)
            postFlagsEvent(virtualKey: vk, down: true, flags: accumulated)
        }

        let down = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
        down?.flags = flags
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
        up?.flags = flags
        up?.post(tap: .cghidEventTap)

        for (vk, mask) in needed.reversed() {
            accumulated.remove(mask)
            postFlagsEvent(virtualKey: vk, down: false, flags: accumulated)
        }
    }

    private func postFlagsEvent(virtualKey: CGKeyCode, down: Bool, flags: CGEventFlags) {
        let e = CGEvent(keyboardEventSource: src, virtualKey: virtualKey, keyDown: down)
        e?.type = .flagsChanged
        e?.flags = flags
        e?.post(tap: .cghidEventTap)
    }
}
#endif
