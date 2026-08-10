//
//  TouchBarService.swift
//  Flow
//
//  Created by Riptik Jhajhria on 28/05/26.
//

#if canImport(AppKit)
import AppKit
import CoreGraphics

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

    private func pollAppState() {
        guard let front = NSWorkspace.shared.frontmostApplication else { return }
        let bundleID = front.bundleIdentifier ?? ""
        let appName  = front.localizedName ?? ""
        if bundleID != lastBundleID {
            lastBundleID = bundleID
            lastTabHash  = 0
            lastXcodeHash = 0
            RemoteConnectionManager.shared.send(.touchBarAppState(bundleID: bundleID, appName: appName))
        }
    }

    private func pollBrowserTabs() {
        guard isBrowserBundle(lastBundleID) else { return }
        let bundleID = lastBundleID
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let tabs = self.fetchTabs(bundleID: bundleID)
            let hash = tabs.map { $0.url + "|" + $0.title }.joined().hashValue
            guard hash != self.lastTabHash else { return }
            self.lastTabHash = hash
            Task { @MainActor in
                RemoteConnectionManager.shared.send(.touchBarBrowserTabs(tabs: tabs))
            }
        }
    }

    private func pollXcodeFiles() {
        guard lastBundleID == "com.apple.dt.Xcode" else { return }
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            let files = self.fetchXcodeOpenFiles()
            let hash = files.map { $0.path }.joined().hashValue
            guard hash != self.lastXcodeHash else { return }
            self.lastXcodeHash = hash
            Task { @MainActor in
                RemoteConnectionManager.shared.send(.touchBarXcodeFiles(files: files))
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
        var errorDict: NSDictionary?
        var result: NSAppleEventDescriptor = NSAppleEventDescriptor()
        if Thread.isMainThread {
            guard let appleScript = NSAppleScript(source: script) else { return [] }
            result = appleScript.executeAndReturnError(&errorDict)
        } else {
            DispatchQueue.main.sync {
                guard let appleScript = NSAppleScript(source: script) else { return }
                result = appleScript.executeAndReturnError(&errorDict)
            }
        }
        guard errorDict == nil else { return [] }
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
        var errorDict: NSDictionary?
        var result = NSAppleEventDescriptor()
        if Thread.isMainThread {
            guard let s = NSAppleScript(source: script) else { return [] }
            result = s.executeAndReturnError(&errorDict)
        } else {
            DispatchQueue.main.sync {
                guard let s = NSAppleScript(source: script) else { return }
                result = s.executeAndReturnError(&errorDict)
            }
        }
        guard errorDict == nil, result.numberOfItems > 0 else { return [] }
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
                reply(.touchBarAppState(bundleID: bundleID, appName: appName))
                if self.isBrowserBundle(bundleID) {
                    DispatchQueue.global(qos: .userInitiated).async {
                        let tabs = self.fetchTabs(bundleID: bundleID)
                        self.lastTabHash = tabs.map { $0.url + "|" + $0.title }.joined().hashValue
                        reply(.touchBarBrowserTabs(tabs: tabs))
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
            perform(kind)
        case .muteAudio, .unmuteAudio:
            postSystemDefinedKey(NX_KEYTYPE_MUTE)
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

    private func perform(_ kind: TouchBarActionKind) {
        switch kind {
        case .brightnessUp:   keyTapWithFlags(120, flags: .maskSecondaryFn)
        case .brightnessDown: keyTapWithFlags(122, flags: .maskSecondaryFn)
        case .keyboardBrightnessUp:   postSystemDefinedKey(NX_KEYTYPE_ILLUMINATION_UP)
        case .keyboardBrightnessDown: postSystemDefinedKey(NX_KEYTYPE_ILLUMINATION_DOWN)
        case .volumeUp:       adjustVolume(by: 6)
        case .volumeDown:     adjustVolume(by: -6)
        case .mute:           toggleMute()
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
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.exposelauncher") {
                NSWorkspace.shared.open(url)
            } else {
                self.keyTapWithFlags(99, flags: .maskSecondaryFn)
            }
        }
    }

    private func triggerAppWindows() {
        keyTapWithFlags(109, flags: .maskSecondaryFn)
    }

    private func runScript(_ source: String) {
        let block = {
            var err: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&err)
        }
        if Thread.isMainThread { block() } else { DispatchQueue.main.sync { block() } }
    }

    private func openLaunchpad() {
        DispatchQueue.main.async {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.launchpad.launcher")
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

    private func adjustVolume(by delta: Int) {
        runScript("""
        set c to output volume of (get volume settings)
        set n to c + (\(delta))
        if n > 100 then set n to 100
        if n < 0 then set n to 0
        set volume output volume n
        """)
    }

    private func toggleMute() {
        runScript("""
        set m to output muted of (get volume settings)
        set volume output muted (not m)
        """)
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

