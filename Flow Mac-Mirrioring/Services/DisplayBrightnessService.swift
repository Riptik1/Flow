//
//  DisplayBrightnessService.swift
//  Flow
//
//  Sets the Mac's screen brightness to an exact level (0...1) for the phone's
//  "privacy" slider. 0 turns the backlight fully off so nobody nearby can see
//  that the Mac is running, while screen capture keeps working.
//

#if canImport(AppKit)
import AppKit
import CoreGraphics

final class DisplayBrightnessService {
    static let shared = DisplayBrightnessService()

    private let queue = DispatchQueue(label: "com.flow.brightness", qos: .userInteractive)

    private typealias DSGet = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias DSSet = @convention(c) (UInt32, Float) -> Int32
    private lazy var api: (get: DSGet, set: DSSet)? = {
        guard let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let g = dlsym(h, "DisplayServicesGetBrightness"),
              let s = dlsym(h, "DisplayServicesSetBrightness") else { return nil }
        return (unsafeBitCast(g, to: DSGet.self), unsafeBitCast(s, to: DSSet.self))
    }()

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .setDisplayBrightness(let level):
            queue.async { [self] in apply(level: level) }
        case .requestDisplayBrightness:
            queue.async { [self] in reply(.displayBrightness(level: currentLevel() ?? 1)) }
        default:
            break
        }
    }

    private func activeDisplays() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &count)
        guard count > 0 else { return [CGMainDisplayID()] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetActiveDisplayList(count, &ids, &count)
        // Built-in panel first: it is the one DisplayServices can always drive.
        return ids.prefix(Int(count)).sorted { CGDisplayIsBuiltin($0) != 0 && CGDisplayIsBuiltin($1) == 0 }
    }

    private func currentLevel() -> Float? {
        guard let api else { return nil }
        for display in activeDisplays() {
            var value: Float = 0
            if api.get(display, &value) == 0 { return min(1, max(0, value)) }
        }
        return nil
    }

    private func apply(level: Float) {
        guard let api else { return }
        let value = min(1, max(0, level))
        for display in activeDisplays() {
            // Displays that don't support software brightness simply refuse; skip them.
            _ = api.set(display, value)
        }
    }
}
#endif
