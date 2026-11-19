//
//  MacPermissionManager.swift
//  Flow Mac-Mirrioring
//
//  Central place for the permissions the Mac app needs. It
//  - walks the user through them on first launch,
//  - warns (popup) when the iPhone connects and something is still missing,
//  - blocks a remote action that needs a missing permission and tells the user why.
//

#if canImport(AppKit)
import AppKit
import ApplicationServices
import CoreGraphics
import IOKit.hid

enum MacPermissionKind: CaseIterable {
    case accessibility
    case screenRecording

    var title: String {
        switch self {
        case .accessibility:   return "Accessibility"
        case .screenRecording: return "Screen Recording"
        }
    }

    /// What stops working without it – shown in the popup.
    var consequence: String {
        switch self {
        case .accessibility:
            return "mouse, keyboard and trackpad control"
        case .screenRecording:
            return "app mirroring"
        }
    }

    var settingsURL: URL {
        let pane: String
        switch self {
        case .accessibility:   pane = "Privacy_Accessibility"
        case .screenRecording: pane = "Privacy_ScreenCapture"
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")!
    }
}

final class MacPermissionManager {
    static let shared = MacPermissionManager()

    private let onboardingKey = "flow.mac.permissionOnboardingDone"
    private var lastWarning: [String: Date] = [:]
    private var alertVisible = false

    private init() {}

    // MARK: - Status

    func isGranted(_ kind: MacPermissionKind) -> Bool {
        switch kind {
        case .accessibility:
            return AXIsProcessTrusted()
        case .screenRecording:
            return CGPreflightScreenCaptureAccess()
        }
    }

    var missing: [MacPermissionKind] {
        MacPermissionKind.allCases.filter { !isGranted($0) }
    }

    func request(_ kind: MacPermissionKind) {
        switch kind {
        case .accessibility:
            let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(opts)
        case .screenRecording:
            requestScreenRecording()
        }
    }

    /// Shows macOS's own "Flow would like to record this Mac's screen" prompt. Calling this
    /// is also what makes Flow appear in System Settings -> Screen Recording.
    func requestScreenRecording() {
        guard !CGPreflightScreenCaptureAccess() else { return }
        let asked = UserDefaults.standard.bool(forKey: "flow.mac.askedScreenRecording")
        UserDefaults.standard.set(true, forKey: "flow.mac.askedScreenRecording")
        _ = CGRequestScreenCaptureAccess()
        // macOS shows its prompt only once. If the user dismissed it earlier, offer the
        // Settings pane through our own dialog instead of silently doing nothing.
        if asked {
            showAlert(
                key: "screenSettings",
                minInterval: 20,
                title: "Screen Recording is off",
                body: "Turn on Flow in System Settings, then reopen Flow.",
                settings: MacPermissionKind.screenRecording.settingsURL
            )
        }
    }

    // MARK: - First launch

    func runFirstLaunchOnboarding() {
        guard !UserDefaults.standard.bool(forKey: onboardingKey) else {
            // Returning user: just make sure nothing silently broke.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                self?.warnIfMissing(reason: nil, throttleKey: "launch")
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = "Allow Flow to control this Mac"
            alert.informativeText = """
            Flow needs two permissions:

            • Accessibility – mouse and keyboard
            • Screen Recording – app mirroring

            Click Allow when macOS asks.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Continue")
            alert.addButton(withTitle: "Later")
            let proceed = alert.runModal() == .alertFirstButtonReturn
            UserDefaults.standard.set(true, forKey: self.onboardingKey)
            guard proceed else { return }
            for kind in MacPermissionKind.allCases where !self.isGranted(kind) {
                self.request(kind)
            }
        }
    }

    // MARK: - Warnings

    /// Popup listing everything that is still not allowed.
    func warnIfMissing(reason: String?, throttleKey: String = "general", minInterval: TimeInterval = 120) {
        let list = missing
        guard !list.isEmpty else { return }
        showAlert(
            key: throttleKey,
            minInterval: minInterval,
            title: "Permission needed",
            body: "Turn on Flow for these, or the features won't work:\n\n"
                + list.map { "• \($0.title) – \($0.consequence)" }.joined(separator: "\n"),
            settings: list.first!.settingsURL
        )
    }

    /// Returns true if the message may run; otherwise warns and returns false.
    func allows(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) -> Bool {
        guard let kind = requirement(for: message) else { return true }
        let needed: [MacPermissionKind]
        switch kind {
        case .input:     needed = [.accessibility]
        case .mirroring: needed = [.screenRecording, .accessibility]
        }
        let notAllowed = needed.filter { !isGranted($0) }
        guard !notAllowed.isEmpty else { return true }

        if notAllowed.contains(.screenRecording) {
            DispatchQueue.main.async { [self] in
                requestScreenRecording()
            }
            reply(.appMirroringError(error: "Screen Recording is off on your Mac. Click Allow on the Mac."))
            if notAllowed == [.screenRecording] { return false }
        }
        let accessibilityOnly = notAllowed.filter { $0 != .screenRecording }
        guard !accessibilityOnly.isEmpty else { return false }
        let names = accessibilityOnly.map { $0.title }.joined(separator: " and ")
        let feature = kind == .input ? "remote control" : "app mirroring"
        let key = "feature-\(kind)"
        showAlert(
            key: key,
            minInterval: 45,
            title: "\(names) is off",
            body: "Your iPhone can't use \(feature) until you turn on Flow in System Settings.",
            settings: accessibilityOnly[0].settingsURL,
            onShown: {
                let text = "\(names) is off on your Mac. Turn it on in System Settings."
                reply(kind == .mirroring ? .appMirroringError(error: text) : .operationFailure(error: text))
            }
        )
        return false
    }

    private enum Requirement { case input, mirroring }

    private func requirement(for message: FlowMessage) -> Requirement? {
        switch message {
        case .mouseMove, .leftClick, .rightClick, .doubleClick,
             .scrollBegan, .scroll, .scrollEnded,
             .magnifyBegan, .magnify, .magnifyEnded, .smartZoom, .swipe,
             .clickDragBegin, .clickDragMove, .clickDragEnd,
             .threeFingerDragBegin, .threeFingerDragMove, .threeFingerDragEnd,
             .keyPress, .typeText,
             .appMirroringInputTouch, .appMirroringInputClick, .appMirroringInputScroll,
             .appMirroringInputKey, .appMirroringInputRightClick,
             .appMirroringInputDoubleClick, .appMirroringInputText:
            return .input
        case .touchBarAction(let kind):
            // Volume, mute and brightness are changed directly and need no permission.
            switch kind {
            case .volumeUp, .volumeDown, .mute, .brightnessUp, .brightnessDown, .missionControl, .launchpad:
                return nil
            default:
                return .input
            }
        case .startAppMirroring:
            return .mirroring
        default:
            return nil
        }
    }

    /// The user refused "Flow wants to control <browser>" – tabs can't be listed until it is allowed.
    func warnAutomationDenied(appName: String) {
        showAlert(
            key: "automation-\(appName)",
            minInterval: 600,
            title: "Allow Flow to control \(appName)",
            body: "Flow needs it to show your \(appName) tabs on the Touch Bar. Turn on \(appName) under Flow in Automation.",
            settings: URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
        )
    }

    /// Always runs on the main thread; throttled so a stream of blocked messages
    /// shows one popup, not hundreds.
    private func showAlert(key: String, minInterval: TimeInterval, title: String, body: String,
                           settings: URL, onShown: (() -> Void)? = nil) {
        DispatchQueue.main.async { [self] in
            if let last = lastWarning[key], Date().timeIntervalSince(last) < minInterval { return }
            guard !alertVisible else { return }
            lastWarning[key] = Date()
            alertVisible = true
            onShown?()
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = body
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Not Now")
            let open = alert.runModal() == .alertFirstButtonReturn
            alertVisible = false
            if open { NSWorkspace.shared.open(settings) }
        }
    }
}
#endif
