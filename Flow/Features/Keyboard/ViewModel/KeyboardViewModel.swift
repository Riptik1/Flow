//
//  KeyboardViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import Combine
import SwiftUI

final class KeyboardViewModel: ObservableObject {
    @Published var capsOn = false
    @Published var shiftOn = false
    @Published var controlOn = false
    @Published var optionOn = false
    @Published var commandOn = false
    @Published var fnOn = false
    @Published var isMuted = false
    @Published var showEmoji = false
    @Published var frontApp = AppContext(bundleID: "", appName: "")
    @Published var browserTabs: [TouchBarTab] = []
    @Published var xcodeFiles: [XcodeRecentFile] = []

    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()

    var currentMods: Int {
        var f: UInt64 = 0
        if shiftOn   { f |= 0x00020000 }
        if controlOn { f |= 0x00040000 }
        if optionOn  { f |= 0x00080000 }
        if commandOn { f |= 0x00100000 }
        if capsOn    { f |= 0x00010000 }
        if fnOn      { f |= 0x00800000 }
        return Int(f)
    }

    var activeKeys: [String: Bool] {
        var d: [String: Bool] = [:]
        d["shift"]     = shiftOn
        d["control"]   = controlOn
        d["option"]    = optionOn
        d["command"]   = commandOn
        d["fn"]        = fnOn
        d["caps lock"] = capsOn
        return d
    }

    init(connectionService: FlowConnectionServicing = LiveFlowConnectionService.shared) {
        self.connectionService = connectionService
        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handle($0) }
            .store(in: &cancellables)
    }

    func requestTouchBarState() {
        connectionService.send(.touchBarStateRequest)
    }

    func toggleMute() {
        isMuted.toggle()
        connectionService.send(isMuted ? .muteAudio : .unmuteAudio)
    }

    func send(_ message: FlowMessage) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        connectionService.send(message)
    }

    func sendArrow(_ direction: String) {
        guard let code = KeyboardLayout.arrowKeyCodes[direction] else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        connectionService.send(.keyPress(keyCode: code, modifiers: currentMods))
    }

    func handleKey(_ key: MKey) {
        switch key.kind {
        case .capsLock:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            capsOn.toggle()
        case .modifier:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            switch key.label {
            case "shift":   shiftOn.toggle()
            case "control": controlOn.toggle()
            case "option":  optionOn.toggle()
            case "command": commandOn.toggle()
            default: break
            }
        case .fn:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            fnOn.toggle()
        default:
            guard let code = KeyboardLayout.keyCodes[key.label.lowercased()] else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            connectionService.send(.keyPress(keyCode: code, modifiers: currentMods))
            shiftOn = false; controlOn = false; optionOn = false; commandOn = false
        }
    }

    func typeString(_ s: String) {
        var delay = 0.0
        for ch in s {
            let lower = Character(ch.lowercased())
            guard let ev = KeyboardLayout.typingCharCodes[ch]
                ?? KeyboardLayout.typingCharCodes[lower].map({ ($0.code, ch.isUppercase || $0.shift) })
            else { continue }
            let connectionService = self.connectionService
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                connectionService.send(.keyPress(keyCode: ev.code, modifiers: ev.shift ? 0x00020000 : 0))
            }
            delay += 0.04
        }
    }

    /// iPhone: the keyboard only makes sense sideways, so lock to landscape (left or right).
    /// iPad: portrait and landscape are both fine – the layout adapts to either.
    func forceLandscape() {
        if UIDevice.current.userInterfaceIdiom == .pad {
            unlockOrientation()
            return
        }
        AppDelegate.orientationLock = .landscape
        if #available(iOS 16.0, *) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { _ in }
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }

    func unlockOrientation() {
        AppDelegate.orientationLock = .all
        if #available(iOS 16.0, *) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .all)) { _ in }
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }

    private func handle(_ message: FlowMessage) {
        switch message {
        case .touchBarAppState(let bID, let name):
            withAnimation(.easeInOut(duration: 0.2)) {
                frontApp = AppContext(bundleID: bID, appName: name)
                if !frontApp.isBrowser  { browserTabs = [] }
                if !frontApp.isXcode    { xcodeFiles  = [] }
                if !frontApp.wantsEmoji { showEmoji   = false }
            }
        case .touchBarBrowserTabs(let tabs):
            withAnimation { browserTabs = tabs }
        case .touchBarXcodeFiles(let files):
            withAnimation { xcodeFiles = files }
        case .touchBarFavicon(let host, let png):
            FaviconStore.shared.set(host: host, png: png)
        case .muteStateChanged(let muted):
            isMuted = muted
        default:
            break
        }
    }
}
