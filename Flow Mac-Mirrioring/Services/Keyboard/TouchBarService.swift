//
//  TouchBarService.swift
//  Flow
//
//  Created by Riptik Jhajhria on 28/05/26.
//

#if canImport(AppKit)
import AppKit
import CoreGraphics
import CoreAudio

private let NX_KEYTYPE_SOUND_UP: Int32 = 0
private let NX_KEYTYPE_SOUND_DOWN: Int32 = 1
private let NX_KEYTYPE_BRIGHTNESS_UP: Int32 = 2
private let NX_KEYTYPE_BRIGHTNESS_DOWN: Int32 = 3
private let NX_KEYTYPE_MUTE: Int32 = 7
private let NX_KEYTYPE_ILLUMINATION_UP: Int32 = 21
private let NX_KEYTYPE_ILLUMINATION_DOWN: Int32 = 22
private let NX_KEYTYPE_PLAY: Int32 = 16
private let NX_KEYTYPE_NEXT: Int32 = 17
private let NX_KEYTYPE_PREVIOUS: Int32 = 18

final class TouchBarService {
    static let shared = TouchBarService()

    private let src: CGEventSource? = CGEventSource(stateID: .hidSystemState)
    private let queue = DispatchQueue(label: "com.flow.touchbar", qos: .userInteractive)
    private let stateLock = NSLock()
    private var pollTimer: Timer?
    private var tabTimer: Timer?
    private var xcodeTimer: Timer?
    private var _lastBundleID  = ""
    private var _lastTabHash   = 0
    private var _lastXcodeHash = 0

    private var lastBundleID: String {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _lastBundleID }
        set { stateLock.lock(); defer { stateLock.unlock() }; _lastBundleID = newValue }
    }
    private var lastTabHash: Int {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _lastTabHash }
        set { stateLock.lock(); defer { stateLock.unlock() }; _lastTabHash = newValue }
    }
    private var lastXcodeHash: Int {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _lastXcodeHash }
        set { stateLock.lock(); defer { stateLock.unlock() }; _lastXcodeHash = newValue }
    }

    private init() {
        DispatchQueue.main.async { self.startPolling() }
    }

    private func startPolling() {
        let pt = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in self?.pollAppState() }
        pt.tolerance = 0.3
        RunLoop.main.add(pt, forMode: .common)
        pollTimer = pt

        let tt = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in self?.pollBrowserTabs() }
        tt.tolerance = 0.5
        RunLoop.main.add(tt, forMode: .common)
        tabTimer = tt

        let xt = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in self?.pollXcodeFiles() }
        xt.tolerance = 0.5
        RunLoop.main.add(xt, forMode: .common)
        xcodeTimer = xt
    }

    private var phoneConnected: Bool { FlowConnectionRepository.shared.state == .connected }

    private func pollAppState() {
        guard phoneConnected else { lastBundleID = ""; return }
        guard let front = NSWorkspace.shared.frontmostApplication else { return }
        let bundleID = front.bundleIdentifier ?? ""
        let appName  = front.localizedName ?? ""
        if bundleID != lastBundleID {
            lastBundleID = bundleID
            lastTabHash  = 0
            lastXcodeHash = 0
            FlowConnectionRepository.shared.send(.touchBarAppState(bundleID: bundleID, appName: appName))
        }
    }

    private func pollBrowserTabs() {
        guard phoneConnected, isBrowserBundle(lastBundleID) else { return }
        let bundleID = lastBundleID
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let tabs = self.fetchTabs(bundleID: bundleID)
            self.syncFavicons(for: tabs)
            let hash = tabs.map { $0.url + "|" + $0.title + "|" + ($0.isActive ? "1" : "0") }.joined().hashValue
            guard hash != self.lastTabHash else { return }
            self.lastTabHash = hash
            Task { @MainActor in
                FlowConnectionRepository.shared.send(.touchBarBrowserTabs(tabs: tabs))
            }
        }
    }

    private func pollXcodeFiles() {
        guard phoneConnected, lastBundleID == "com.apple.dt.Xcode" else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let files = self.fetchXcodeOpenFiles()
            let hash = files.map { $0.path }.joined().hashValue
            guard hash != self.lastXcodeHash else { return }
            self.lastXcodeHash = hash
            Task { @MainActor in
                FlowConnectionRepository.shared.send(.touchBarXcodeFiles(files: files))
            }
        }
    }

    private func isBrowserBundle(_ id: String) -> Bool {
        ["com.apple.Safari","com.brave.Browser","org.mozilla.firefox",
         "com.google.Chrome","com.microsoft.edgemac","com.operasoftware.Opera",
         "com.vivaldi.Vivaldi","com.apple.SafariTechnologyPreview"].contains(id)
    }

    private func chromiumAppName(for bundleID: String) -> String {
        switch bundleID {
        case "com.brave.Browser":       return "Brave Browser"
        case "org.mozilla.firefox":     return "Firefox"
        case "com.google.Chrome":       return "Google Chrome"
        case "com.microsoft.edgemac":   return "Microsoft Edge"
        case "com.operasoftware.Opera": return "Opera"
        case "com.vivaldi.Vivaldi":     return "Vivaldi"
        default:                        return "Google Chrome"
        }
    }

    private func fetchTabs(bundleID: String) -> [TouchBarTab] {
        let scripted = fetchTabsViaScript(bundleID: bundleID)
        if !scripted.isEmpty { return scripted }
        return fetchTabsViaAccessibility(bundleID: bundleID)
    }

    private func fetchTabsViaAccessibility(bundleID: String) -> [TouchBarTab] {
        guard let app = NSWorkspace.shared.runningApplications
            .first(where: { $0.bundleIdentifier == bundleID }) else { return [] }
        let pid = app.processIdentifier
        let axApp = AXUIElementCreateApplication(pid)

        var windowsVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsVal) == .success,
              let windows = windowsVal as? [AXUIElement], !windows.isEmpty else { return [] }
        let front = windows[0]

        let tabs = collectTabElements(from: front, depth: 0)
        if tabs.isEmpty {
            var titleVal: CFTypeRef?
            AXUIElementCopyAttributeValue(front, kAXTitleAttribute as CFString, &titleVal)
            let title = (titleVal as? String) ?? "Browser"
            return [TouchBarTab(id: UUID(), title: title.isEmpty ? "Browser" : title, url: "", isActive: true)]
        }
        return tabs
    }

    private func collectTabElements(from element: AXUIElement, depth: Int) -> [TouchBarTab] {
        guard depth < 8 else { return [] }

        var roleVal: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleVal)
        let role = (roleVal as? String) ?? ""

        var childrenVal: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenVal)
        let children = (childrenVal as? [AXUIElement]) ?? []

        if role == "AXTabGroup" || role == "AXToolbar" {
            let tabs = extractTabsFromGroup(children: children)
            if !tabs.isEmpty { return tabs }
        }

        for child in children {
            let found = collectTabElements(from: child, depth: depth + 1)
            if !found.isEmpty { return found }
        }

        return []
    }

    private func extractTabsFromGroup(children: [AXUIElement]) -> [TouchBarTab] {
        var tabs: [TouchBarTab] = []
        var candidates: [AXUIElement] = []

        for child in children {
            var roleVal: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleVal)
            let role = (roleVal as? String) ?? ""
            if role == "AXRadioButton" || role == "AXTab" {
                candidates.append(child)
            } else if role == "AXGroup" || role == "AXScrollArea" {
                var subChildrenVal: CFTypeRef?
                AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subChildrenVal)
                if let subChildren = subChildrenVal as? [AXUIElement] {
                    for sub in subChildren {
                        var subRoleVal: CFTypeRef?
                        AXUIElementCopyAttributeValue(sub, kAXRoleAttribute as CFString, &subRoleVal)
                        let subRole = (subRoleVal as? String) ?? ""
                        if subRole == "AXRadioButton" || subRole == "AXTab" {
                            candidates.append(sub)
                        }
                    }
                }
            }
        }

        for (i, child) in candidates.prefix(12).enumerated() {
            var titleVal: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXTitleAttribute as CFString, &titleVal)
            let title = (titleVal as? String) ?? ""
            guard !title.isEmpty else { continue }

            var selectedVal: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXValueAttribute as CFString, &selectedVal)
            let isActive: Bool
            if let n = selectedVal as? Int { isActive = n == 1 }
            else if let b = selectedVal as? Bool { isActive = b }
            else { isActive = (i == 0) }

            tabs.append(TouchBarTab(id: UUID(), title: title, url: "", isActive: isActive))
        }
        return tabs
    }

    private func fetchTabsViaScript(bundleID: String) -> [TouchBarTab] {
        let isSafari = bundleID.contains("Safari")
        let script: String
        if isSafari {
            script = """
            tell application "Safari"
                set out to {}
                try
                    set w to front window
                    set activeT to missing value
                    try
                        set activeT to current tab of w
                    end try
                    repeat with t in tabs of w
                        set tTitle to "New Tab"
                        set tURL to ""
                        try
                            set tTitle to name of t
                        end try
                        try
                            set tURL to URL of t
                        end try
                        if activeT is not missing value and t is activeT then
                            set af to "1"
                        else
                            set af to "0"
                        end if
                        set end of out to (tTitle as string) & "|||" & (tURL as string) & "|||" & af
                    end repeat
                end try
                return out
            end tell
            """
        } else {
            let appName = chromiumAppName(for: bundleID)
            script = """
            tell application "\(appName)"
                set out to {}
                try
                    set w to front window
                    set activeIdx to 0
                    try
                        set activeIdx to active tab index of w
                    end try
                    set idx to 0
                    repeat with t in tabs of w
                        set idx to idx + 1
                        set tTitle to "New Tab"
                        set tURL to ""
                        try
                            set tTitle to title of t
                        end try
                        try
                            set tURL to URL of t
                        end try
                        if idx is activeIdx then
                            set af to "1"
                        else
                            set af to "0"
                        end if
                        set end of out to (tTitle as string) & "|||" & (tURL as string) & "|||" & af
                    end repeat
                end try
                return out
            end tell
            """
        }
        let appLabel = isSafari ? "Safari" : chromiumAppName(for: bundleID)
        guard let result = executeAppleScript(script, appName: appLabel) else { return [] }
        var tabs: [TouchBarTab] = []
        let count = result.numberOfItems
        guard count > 0 else { return [] }
        for i in 1...count {
            guard let item = result.atIndex(i) else { continue }
            let str = item.stringValue ?? ""
            let parts = str.components(separatedBy: "|||")
            guard parts.count >= 3 else { continue }
            tabs.append(TouchBarTab(
                id: UUID(),
                title: parts[0].isEmpty ? "New Tab" : parts[0],
                url: parts[1],
                isActive: parts[2] == "1"
            ))
        }
        return tabs
    }

    private func activateBrowserTab(at index: Int) {
        let bundleID = lastBundleID
        guard isBrowserBundle(bundleID) else { return }
        let tabIndex = index + 1
        let script: String
        if bundleID.contains("Safari") {
            script = """
            tell application "Safari"
                try
                    set w to front window
                    set t to tab \(tabIndex) of w
                    set current tab of w to t
                end try
            end tell
            """
        } else {
            let appName = chromiumAppName(for: bundleID)
            script = """
            tell application "\(appName)"
                try
                    set w to front window
                    set active tab index of w to \(tabIndex)
                end try
            end tell
            """
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.runScript(script)
        }
    }

    private func fetchXcodeOpenFiles() -> [XcodeRecentFile] {
        let script = """
        tell application "Xcode"
            set docs to {}
            try
                repeat with d in source documents
                    set docPath to path of d
                    if docPath is not missing value then
                        set end of docs to docPath
                    end if
                end repeat
            end try
            return docs
        end tell
        """
        guard let result = executeAppleScript(script, appName: "Xcode"), result.numberOfItems > 0 else { return [] }
        var files: [XcodeRecentFile] = []
        for i in 1...result.numberOfItems {
            guard let item = result.atIndex(i) else { continue }
            let path = item.stringValue ?? ""
            guard !path.isEmpty else { continue }
            let url = URL(fileURLWithPath: path)
            files.append(XcodeRecentFile(
                id: UUID(),
                name: url.deletingPathExtension().lastPathComponent,
                path: path,
                ext: url.pathExtension.lowercased()
            ))
        }
        return Array(files.prefix(8))
    }

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        queue.async { [weak self] in self?.process(message, reply: reply) }
    }

    private func process(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .touchBarStateRequest:
            DispatchQueue.main.async {
                guard let front = NSWorkspace.shared.frontmostApplication else { return }
                let bundleID = front.bundleIdentifier ?? ""
                let appName  = front.localizedName ?? ""
                self.lastBundleID  = bundleID
                self.lastTabHash   = 0
                self.lastXcodeHash = 0
                self.resetFaviconsSent()
                reply(.touchBarAppState(bundleID: bundleID, appName: appName))
                if self.isBrowserBundle(bundleID) {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let tabs = self.fetchTabs(bundleID: bundleID)
                        self.lastTabHash = tabs.map { $0.url + "|" + $0.title + "|" + ($0.isActive ? "1" : "0") }.joined().hashValue
                        reply(.touchBarBrowserTabs(tabs: tabs))
                        self.syncFavicons(for: tabs)
                    }
                }
                if bundleID == "com.apple.dt.Xcode" {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let files = self.fetchXcodeOpenFiles()
                        self.lastXcodeHash = files.map { $0.path }.joined().hashValue
                        reply(.touchBarXcodeFiles(files: files))
                    }
                }
            }
        case .touchBarAction(let kind):
            perform(kind, reply: reply)
        case .muteAudio:
            setMuted(true, reply: reply)
        case .unmuteAudio:
            setMuted(false, reply: reply)
        case .typeText(let text):
            setClipboard(text)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.keyTapWithFlags(9, flags: .maskCommand)
            }
        case .setRemoteClipboardText(let text):
            setClipboard(text)
        case .setRemoteClipboardAndPaste(let text):
            setClipboard(text)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.keyTapWithFlags(9, flags: .maskCommand)
            }
        default:
            break
        }
    }

    private func setClipboard(_ text: String) {
        DispatchQueue.main.async {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }
    }

    private func perform(_ kind: TouchBarActionKind, reply: @escaping (FlowMessage) -> Void) {
        switch kind {
        case .brightnessUp:   adjustBrightness(steps: 1)
        case .brightnessDown: adjustBrightness(steps: -1)
        case .keyboardBrightnessUp:   postSystemDefinedKey(NX_KEYTYPE_ILLUMINATION_UP)
        case .keyboardBrightnessDown: postSystemDefinedKey(NX_KEYTYPE_ILLUMINATION_DOWN)
        case .volumeUp:       adjustVolume(steps: 1, reply: reply)
        case .volumeDown:     adjustVolume(steps: -1, reply: reply)
        case .mute:           setMuted(!isMuted(), reply: reply)
        case .mediaPlay:      postSystemDefinedKey(NX_KEYTYPE_PLAY)
        case .mediaPrev:      postSystemDefinedKey(NX_KEYTYPE_PREVIOUS)
        case .mediaNext:      postSystemDefinedKey(NX_KEYTYPE_NEXT)
        case .sleep:
            keyTapWithFlags(81, flags: [.maskCommand, .maskAlternate])
        case .lockScreen:
            keyTapWithFlags(12, flags: [.maskCommand, .maskControl])
        case .doNotDisturb:
            toggleDoNotDisturb()
        case .switchBrowserTab(let index):
            activateBrowserTab(at: index)
        case .browserBack:
            keyTapWithFlags(123, flags: .maskCommand)
        case .browserForward:
            keyTapWithFlags(124, flags: .maskCommand)
        case .newBrowserTab:
            keyTapWithFlags(17, flags: .maskCommand)
        case .closeBrowserTab:
            keyTapWithFlags(13, flags: .maskCommand)
        case .reopenClosedTab:
            keyTapWithFlags(13, flags: [.maskCommand, .maskShift])
        case .openXcodeFile(let index):
            openXcodeFile(at: index)
        case .missionControl:
            triggerMissionControl()
        case .appWindows:
            triggerAppWindows()
        case .launchpad:
            openLaunchpad()
        case .showDesktop:
            keyTapWithFlags(103, flags: .maskSecondaryFn)
        case .spotlight:
            keyTapWithFlags(49, flags: .maskCommand)
        }
    }

    private func triggerMissionControl() {
        DispatchQueue.main.async {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Mission Control.app"))
        }
    }

    private func triggerAppWindows() {
        keyTapWithFlags(125, flags: [.maskControl, .maskSecondaryFn])
    }

    /// AppleScript runs on its own serial queue: a pending macOS "Allow Flow to control Safari?"
    /// prompt (or a slow app) must never freeze the Mac app's UI or the other Touch Bar actions.
    private let scriptQueue = DispatchQueue(label: "com.flow.touchbar.applescript", qos: .userInitiated)

    private func executeAppleScript(_ source: String, appName: String? = nil) -> NSAppleEventDescriptor? {
        var result: NSAppleEventDescriptor?
        var errorNumber: Int?
        scriptQueue.sync {
            var err: NSDictionary?
            let r = NSAppleScript(source: source)?.executeAndReturnError(&err)
            if let err {
                errorNumber = err[NSAppleScript.errorNumber] as? Int
            } else {
                result = r
            }
        }
        if errorNumber == -1743, let appName {
            // "Not authorized to send Apple events" – the user said no to the Automation prompt.
            MacPermissionManager.shared.warnAutomationDenied(appName: appName)
        }
        return result
    }

    private func runScript(_ source: String) {
        scriptQueue.async {
            var err: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&err)
        }
    }

    private func openLaunchpad() {
        DispatchQueue.main.async {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.apps.launcher")
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.launchpad.launcher")
                ?? NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.launchpad") {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
            }
        }
    }

    private func postSystemDefinedKey(_ keyType: Int32) {
        DispatchQueue.main.async {
            for down in [true, false] {
                let keyState: Int = down ? 0xa : 0xb
                let data1 = (Int(keyType) << 16) | (keyState << 8)
                let flags = NSEvent.ModifierFlags(rawValue: UInt(data1 & 0xFFFF))
                guard let nsEvent = NSEvent.otherEvent(
                    with: .systemDefined,
                    location: NSPoint.zero,
                    modifierFlags: flags,
                    timestamp: ProcessInfo.processInfo.systemUptime,
                    windowNumber: 0,
                    context: nil,
                    subtype: 8,
                    data1: data1,
                    data2: -1
                ) else { continue }
                guard let cgEvent = nsEvent.cgEvent else { continue }
                cgEvent.post(tap: .cghidEventTap)
            }
        }
    }

    // MARK: - Volume, mute, brightness (no Accessibility needed)

    private func outputDevice() -> AudioDeviceID {
        var id = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain)
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &id)
        return id
    }

    private func outputAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
    }

    /// 'vmvc' = virtual main volume: the same value the menu-bar slider changes.
    private let virtualMainVolume: AudioObjectPropertySelector = 0x766D7663

    private func currentVolume() -> Float? {
        let device = outputDevice()
        var address = outputAddress(virtualMainVolume)
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private func writeVolume(_ value: Float) -> Bool {
        let device = outputDevice()
        var address = outputAddress(virtualMainVolume)
        guard AudioObjectHasProperty(device, &address) else { return false }
        var v = Float32(min(1, max(0, value)))
        return AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &v) == noErr
    }

    private func adjustVolume(steps: Int, reply: @escaping (FlowMessage) -> Void) {
        if let current = currentVolume() {
            let next = current + Float(steps) / 16.0
            if writeVolume(next) {
                if steps > 0, isMuted() { setMuted(false, reply: reply) }
                return
            }
        }
        // Devices without a software volume (some HDMI/USB outputs): ask AppleScript.
        runScript("""
        set c to output volume of (get volume settings)
        set n to c + (\(steps * 6))
        if n > 100 then set n to 100
        if n < 0 then set n to 0
        set volume output volume n
        """)
    }

    private func isMuted() -> Bool {
        let device = outputDevice()
        var address = outputAddress(kAudioDevicePropertyMute)
        guard AudioObjectHasProperty(device, &address) else { return false }
        var value = UInt32(0)
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr else { return false }
        return value != 0
    }

    private func setMuted(_ muted: Bool, reply: @escaping (FlowMessage) -> Void) {
        let device = outputDevice()
        var address = outputAddress(kAudioDevicePropertyMute)
        var done = false
        if AudioObjectHasProperty(device, &address) {
            var v = UInt32(muted ? 1 : 0)
            done = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &v) == noErr
        }
        if !done {
            runScript("set volume output muted \(muted ? "true" : "false")")
        }
        reply(.muteStateChanged(isMuted: muted))
    }

    private typealias DSGet = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias DSSet = @convention(c) (UInt32, Float) -> Int32
    private lazy var displayServices: (get: DSGet, set: DSSet)? = {
        guard let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let g = dlsym(h, "DisplayServicesGetBrightness"),
              let s = dlsym(h, "DisplayServicesSetBrightness") else { return nil }
        return (unsafeBitCast(g, to: DSGet.self), unsafeBitCast(s, to: DSSet.self))
    }()

    /// Built-in display brightness in 16 steps, like the real F1/F2 keys.
    private func adjustBrightness(steps: Int) {
        if let api = displayServices {
            let display = CGMainDisplayID()
            var current: Float = 0
            if api.get(display, &current) == 0 {
                let next = min(1, max(0, current + Float(steps) / 16.0))
                if api.set(display, next) == 0 { return }
            }
        }
        // External display or unsupported Mac: fall back to the brightness media keys.
        postSystemDefinedKey(steps > 0 ? NX_KEYTYPE_BRIGHTNESS_UP : NX_KEYTYPE_BRIGHTNESS_DOWN)
    }

    // MARK: - Browser favicons

    private let faviconLock = NSLock()
    private var faviconCache: [String: Data] = [:]
    private var faviconMissing: [String: Date] = [:]
    private var faviconSent = Set<String>()
    private var faviconLoading = Set<String>()

    private func resetFaviconsSent() {
        faviconLock.lock(); faviconSent.removeAll(); faviconLock.unlock()
    }

    private func host(of urlString: String) -> String? {
        guard let url = URL(string: urlString), let scheme = url.scheme, scheme.hasPrefix("http"),
              let host = url.host, host.contains("."), !host.hasSuffix(".local") else { return nil }
        return host
    }

    /// Sends each site's icon to the phone once (small PNG), so tab buttons can show the real logo.
    private func syncFavicons(for tabs: [TouchBarTab]) {
        for host in Set(tabs.compactMap { host(of: $0.url) }) {
            faviconLock.lock()
            if let png = faviconCache[host] {
                let alreadySent = faviconSent.contains(host)
                faviconSent.insert(host)
                faviconLock.unlock()
                if !alreadySent { sendFavicon(host: host, png: png) }
                continue
            }
            if let missed = faviconMissing[host], Date().timeIntervalSince(missed) < 600 {
                faviconLock.unlock(); continue
            }
            guard !faviconLoading.contains(host) else { faviconLock.unlock(); continue }
            faviconLoading.insert(host)
            faviconLock.unlock()

            Task.detached(priority: .utility) { [weak self] in
                guard let self else { return }
                let png = await self.downloadFavicon(host: host)
                self.faviconLock.lock()
                self.faviconLoading.remove(host)
                if let png {
                    self.faviconCache[host] = png
                    self.faviconSent.insert(host)
                } else {
                    self.faviconMissing[host] = Date()
                }
                self.faviconLock.unlock()
                if let png { self.sendFavicon(host: host, png: png) }
            }
        }
    }

    private func sendFavicon(host: String, png: Data) {
        DispatchQueue.main.async {
            FlowConnectionRepository.shared.send(.touchBarFavicon(host: host, png: png))
        }
    }

    private func downloadFavicon(host: String) async -> Data? {
        if let direct = URL(string: "https://\(host)/favicon.ico"), let png = await loadIcon(direct) { return png }
        // No /favicon.ico: read the page's <link rel="icon">.
        guard let page = URL(string: "https://\(host)/") else { return nil }
        var request = URLRequest(url: page, timeoutInterval: 4)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        let html = String(decoding: data.prefix(200_000), as: UTF8.self)
        guard let tag = html.range(of: "<link[^>]+rel=[\"'](?:shortcut )?icon[\"'][^>]*>", options: [.regularExpression, .caseInsensitive]),
              let hrefRange = String(html[tag]).range(of: "href=[\"']([^\"']+)[\"']", options: [.regularExpression, .caseInsensitive])
        else { return nil }
        let hrefAttr = String(String(html[tag])[hrefRange])
        let href = hrefAttr.dropFirst(5).dropLast()
        guard let iconURL = URL(string: String(href), relativeTo: page)?.absoluteURL else { return nil }
        return await loadIcon(iconURL)
    }

    private func loadIcon(_ url: URL) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 4)
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              data.count > 40, data.count < 400_000,
              let image = NSImage(data: data), image.size.width > 0 else { return nil }
        let size = NSSize(width: 64, height: 64)
        let output = NSImage(size: size)
        output.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size), from: .zero, operation: .copy, fraction: 1)
        output.unlockFocus()
        guard let tiff = output.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    private func toggleDoNotDisturb() {
        runScript("""
        tell application "System Events"
            tell process "Control Center"
                set _items to menu bar items of menu bar 1
                set _focusItem to missing value
                repeat with _item in _items
                    try
                        if (description of _item contains "Focus") or (name of _item contains "Focus") then
                            set _focusItem to _item
                            exit repeat
                        end if
                    end try
                end repeat
                if _focusItem is missing value then
                    repeat with _item in _items
                        try
                            if (description of _item contains "Do Not Disturb") or (name of _item contains "Do Not Disturb") then
                                set _focusItem to _item
                                exit repeat
                            end if
                        end try
                    end repeat
                end if
                if _focusItem is missing value then return
                click _focusItem
                delay 0.35
                set _done to false
                try
                    repeat with _btn in buttons of window 1
                        if (name of _btn contains "Do Not Disturb") or (name of _btn contains "Focus") then
                            click _btn
                            set _done to true
                            exit repeat
                        end if
                    end repeat
                end try
                if not _done then key code 53
            end tell
        end tell
        """)
    }

    private func openXcodeFile(at index: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            let files = self.fetchXcodeOpenFiles()
            guard index < files.count else { return }
            let escaped = files[index].path.replacingOccurrences(of: "\"", with: "\\\"")
            self.runScript("""
            tell application "Xcode"
                activate
                open "\(escaped)"
            end tell
            """)
        }
    }

    private func keyTapWithFlags(_ code: CGKeyCode, flags: CGEventFlags) {
        let d = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: true)
        d?.flags = flags; d?.post(tap: .cghidEventTap)
        let u = CGEvent(keyboardEventSource: src, virtualKey: code, keyDown: false)
        u?.flags = flags; u?.post(tap: .cghidEventTap)
    }
}
#endif

