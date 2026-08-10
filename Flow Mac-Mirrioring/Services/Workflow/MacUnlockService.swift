//
//  MacUnlockService.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/06/26.
//

import Foundation
import AppKit
import CoreGraphics
import Darwin

final class MacUnlockService {
    static let shared = MacUnlockService()

    private var sendMessage: ((FlowMessage) -> Void)?
    private var pollTimer: Timer?
    private var lastSentLockState: Bool? = nil

    private init() {}

    func startMonitoring(send: @escaping (FlowMessage) -> Void) {
        sendMessage = send
        lastSentLockState = nil
        registerObservers()
        sendCurrentStateImmediately()
        startPolling()
    }

    func stopMonitoring() {
        sendMessage = nil
        lastSentLockState = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default.removeObserver(self)
        stopPolling()
    }

    private func registerObservers() {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        DistributedNotificationCenter.default.removeObserver(self)

        let ws = NSWorkspace.shared.notificationCenter

        ws.addObserver(self, selector: #selector(sessionDidResignActive),
                       name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        ws.addObserver(self, selector: #selector(sessionDidBecomeActive),
                       name: NSWorkspace.sessionDidBecomeActiveNotification, object: nil)

        DistributedNotificationCenter.default.addObserver(
            self, selector: #selector(distributedScreenLocked),
            name: .init("com.apple.screenIsLocked"), object: nil)
        DistributedNotificationCenter.default.addObserver(
            self, selector: #selector(distributedScreenUnlocked),
            name: .init("com.apple.screenIsUnlocked"), object: nil)
    }

    @objc private func sessionDidResignActive() {
        sendStateIfChanged(locked: true)
    }

    @objc private func sessionDidBecomeActive() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.sendStateIfChanged(locked: self.checkLockState())
        }
    }

    @objc private func distributedScreenLocked() {
        sendStateIfChanged(locked: true)
    }

    @objc private func distributedScreenUnlocked() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.sendStateIfChanged(locked: false)
        }
    }

    private func sendStateIfChanged(locked: Bool) {
        guard let sendMessage else { return }
        if lastSentLockState != locked {
            lastSentLockState = locked
            sendMessage(.macLockedState(locked: locked))
        }
    }

    func checkLockState() -> Bool {
        if isScreenSaverEngineRunning() { return true }
        guard let dict = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        if let v = dict["ScreenIsLocked"] as? Bool, v { return true }
        if let v = dict["CGSSessionScreenIsLocked"] as? Bool, v { return true }
        if let v = dict["OnConsole"] as? Bool, !v { return true }
        return false
    }

    private func isScreenSaverEngineRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == "com.apple.ScreenSaver.Engine" ||
            $0.localizedName == "ScreenSaverEngine"
        }
    }

    func sendLockState() {
        guard let sendMessage else { return }
        let locked = checkLockState()
        lastSentLockState = locked
        sendMessage(.macLockedState(locked: locked))
    }

    private func sendCurrentStateImmediately() {
        guard let sendMessage else { return }
        let locked = checkLockState()
        lastSentLockState = locked
        sendMessage(.macLockedState(locked: locked))

        for delay in [0.4, 1.0, 2.0, 4.0] as [Double] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, let sendMessage = self.sendMessage else { return }
                let current = self.checkLockState()
                sendMessage(.macLockedState(locked: current))
                self.lastSentLockState = current
            }
        }
    }

    private func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let sendMessage = self.sendMessage else { return }
            let locked = self.checkLockState()
            if self.lastSentLockState != locked {
                self.lastSentLockState = locked
                sendMessage(.macLockedState(locked: locked))
            }
        }
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func fetchProfileImage() -> Data? {
        let user = NSUserName()
        let path = "/var/db/dslocal/nodes/Default/users/\(user).plist"
        if let plist = NSDictionary(contentsOfFile: path),
           let arr = plist["jpegphoto"] as? [Data],
           let data = arr.first { return data }
        return nil
    }

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .wakeMac:
            handleWake()
        case .requestMacUserProfile:
            if let data = fetchProfileImage() { reply(.macUserProfile(imageData: data)) }
            sendLockState()
        default:
            break
        }
    }
}

extension MacUnlockService {
    func handleWake() {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        p.arguments = ["-u", "-t", "3"]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }
}
