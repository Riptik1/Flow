//
//  TerminalService.swift
//  Flow
//
//  Created by Riptik Jhajhria on 30/05/26.
//

import AppKit
import Foundation
import CoreAudio

final class TerminalService {
    static let shared = TerminalService()

    private var sessions: [String: TerminalSession] = [:]
    private let queue = DispatchQueue(label: "com.flow.terminal", qos: .userInteractive)
    private var isMuted: Bool = false

    private init() {
        isMuted = readCurrentMuteState()
    }

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .terminalNewSession(let sid):
            queue.async { [weak self] in
                guard let self else { return }
                let session = TerminalSession(sessionID: sid, reply: reply)
                self.sessions[sid] = session
                session.start()
            }

        case .terminalInput(let sid, let command):
            queue.async { [weak self] in
                self?.sessions[sid]?.write(command)
            }

        case .terminalCloseSession(let sid):
            queue.async { [weak self] in
                self?.sessions[sid]?.close()
                self?.sessions.removeValue(forKey: sid)
            }

        case .spotlightSearch(let query):
            handleSpotlightSearch(query: query, reply: reply)

        case .spotlightOpen(let path):
            openPath(path)

        case .muteAudio:
            setSystemMute(true)
            isMuted = true
            reply(.muteStateChanged(isMuted: true))

        case .unmuteAudio:
            setSystemMute(false)
            isMuted = false
            reply(.muteStateChanged(isMuted: false))

        case .systemLockScreen:
            lockScreen()
            reply(.operationSuccess)

        case .systemShutDown, .systemShutDownForce:
            handleShutdown()

        case .systemRestart:
            restart()

        default:
            break
        }
    }

    private func handleShutdown() {
        DispatchQueue.global(qos: .userInitiated).async {
            let excluded: Set<String> = [
                "Finder", "Flow", "loginwindow", "UserNotificationCenter", "SystemUIServer",
                "Dock", "WindowManager", "ControlCenter", "NotificationCenter", "AirPlayUIAgent", "Spotlight"
            ]
            let targets = NSWorkspace.shared.runningApplications.filter {
                $0.activationPolicy == .regular &&
                !excluded.contains($0.localizedName ?? "") &&
                $0.bundleIdentifier != Bundle.main.bundleIdentifier
            }
            let targetBundleIDs = Set(targets.compactMap { $0.bundleIdentifier })
            for app in targets { app.terminate() }
            Thread.sleep(forTimeInterval: 4.0)
            let nowRunningIDs = Set(
                NSWorkspace.shared.runningApplications
                    .filter { $0.activationPolicy == .regular }
                    .compactMap { $0.bundleIdentifier }
            )
            let stillRunningIDs = targetBundleIDs.intersection(nowRunningIDs)
            if !stillRunningIDs.isEmpty {
                for app in NSWorkspace.shared.runningApplications
                    where stillRunningIDs.contains(app.bundleIdentifier ?? "") {
                    app.forceTerminate()
                }
                Thread.sleep(forTimeInterval: 1.5)
            }
            DispatchQueue.main.async {
                self.runAppleScript("tell application \"System Events\" to shut down")
            }
        }
    }

    private func handleSpotlightSearch(query: String, reply: @escaping (FlowMessage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let results = self.runMDFind(query: query)
            reply(.spotlightResults(results: results))
        }
    }

    private func runMDFind(query: String) -> [SpotlightResult] {
        let process = Process()
        let pipe    = Pipe()
        process.executableURL  = URL(fileURLWithPath: "/usr/bin/mdfind")
        process.arguments      = ["-name", query,
                                  "-onlyin", "/Applications",
                                  "-onlyin", NSHomeDirectory(),
                                  "-onlyin", "/System/Applications"]
        process.standardOutput = pipe
        process.standardError  = Pipe()

        do { try process.run() } catch { return [] }
        process.waitUntilExit()

        let data   = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let paths  = output.components(separatedBy: "\n").filter { !$0.isEmpty }

        return paths.prefix(12).compactMap { path -> SpotlightResult? in
            let url  = URL(fileURLWithPath: path)
            let name = url.deletingPathExtension().lastPathComponent
            let ext  = url.pathExtension.lowercased()

            let kind: String
            switch ext {
            case "app":                                           kind = "Application"
            case "pdf","doc","docx","txt","md","pages":           kind = "Document"
            case "png","jpg","jpeg","gif","heic","tiff","webp":   kind = "Image"
            case "mp4","mov","avi","mkv","m4v":                   kind = "Video"
            case "mp3","m4a","aac","flac","wav","aiff":           kind = "Audio"
            case "zip","tar","gz","rar","7z":                     kind = "Archive"
            default:                                              kind = "File"
            }

            let iconPNG = extractIcon(from: path)
            return SpotlightResult(id: UUID(), name: name, path: path, kind: kind, iconPNG: iconPNG)
        }
    }

    private func extractIcon(from path: String) -> Data? {
        let image = NSWorkspace.shared.icon(forFile: path)
        image.size = NSSize(width: 64, height: 64)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    private func openPath(_ path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func readCurrentMuteState() -> Bool {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)

        var muteVal: UInt32 = 0
        var muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(deviceID, &muteAddr, 0, nil, &muteSize, &muteVal)
        return muteVal == 1
    }

    private func setSystemMute(_ mute: Bool) {
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var hwAddr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &hwAddr, 0, nil, &size, &deviceID)

        var muteVal  = UInt32(mute ? 1 : 0)
        let muteSize = UInt32(MemoryLayout<UInt32>.size)
        var muteAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectSetPropertyData(deviceID, &muteAddr, 0, nil, muteSize, &muteVal)

        let script = mute ? "set volume output muted true" : "set volume output muted false"
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", script]
        try? p.run()
        p.waitUntilExit()
    }

    private func lockScreen() {
        // Lock the screen via screensaver (triggers login window on wake)
        let lockScript = Process()
        lockScript.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        lockScript.arguments = ["-e", "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"]
        lockScript.standardOutput = FileHandle.nullDevice
        lockScript.standardError  = FileHandle.nullDevice
        try? lockScript.run()

        // Turn off the display completely via pmset
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let sleep = Process()
            sleep.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
            sleep.arguments = ["displaysleepnow"]
            sleep.standardOutput = FileHandle.nullDevice
            sleep.standardError  = FileHandle.nullDevice
            try? sleep.run()
        }
    }

    private func restart() {
        runAppleScript("tell application \"System Events\" to restart")
    }

    @discardableResult
    private func runAppleScript(_ script: String) -> String? {
        var error: NSDictionary?
        return NSAppleScript(source: script)?.executeAndReturnError(&error).stringValue
    }
}

final class TerminalSession {
    let sessionID: String
    private let reply: (FlowMessage) -> Void
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?

    private let flushQueue = DispatchQueue(label: "com.flow.terminal.flush")
    private var pendingOutput = ""
    private var pendingError = ""
    private var flushScheduled = false
    private let flushInterval: TimeInterval = 0.08

    init(sessionID: String, reply: @escaping (FlowMessage) -> Void) {
        self.sessionID = sessionID
        self.reply = reply
    }

    func start() {
        let p       = Process()
        let inPipe  = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()

        p.executableURL  = URL(fileURLWithPath: "/bin/zsh")
        p.arguments      = ["-i", "-l"]
        p.standardInput  = inPipe
        p.standardOutput = outPipe
        p.standardError  = errPipe
        p.environment    = ProcessInfo.processInfo.environment

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            self.enqueueOutput(text)
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            self.enqueueError(text)
        }

        p.terminationHandler = { [weak self] _ in
            guard let self else { return }
            self.reply(.terminalError(sessionID: self.sessionID, text: "[Session ended]"))
        }

        do {
            try p.run()
            process   = p
            inputPipe = inPipe
            outputPipe = outPipe
            errorPipe  = errPipe
        } catch {
            reply(.terminalError(sessionID: sessionID, text: "Failed to start shell: \(error.localizedDescription)"))
        }
    }

    private func enqueueOutput(_ text: String) {
        flushQueue.async { [weak self] in
            guard let self else { return }
            self.pendingOutput += text
            self.scheduleFlush()
        }
    }

    private func enqueueError(_ text: String) {
        flushQueue.async { [weak self] in
            guard let self else { return }
            self.pendingError += text
            self.scheduleFlush()
        }
    }

    private func scheduleFlush() {
        guard !flushScheduled else { return }
        flushScheduled = true
        flushQueue.asyncAfter(deadline: .now() + flushInterval) { [weak self] in
            self?.flush()
        }
    }

    private func flush() {
        flushScheduled = false
        if !pendingOutput.isEmpty {
            let text = pendingOutput
            pendingOutput = ""
            reply(.terminalOutput(sessionID: sessionID, text: text))
        }
        if !pendingError.isEmpty {
            let text = pendingError
            pendingError = ""
            reply(.terminalError(sessionID: sessionID, text: text))
        }
    }

    func write(_ command: String) {
        guard let handle = inputPipe?.fileHandleForWriting else { return }
        if let data = (command + "\n").data(using: .utf8) { handle.write(data) }
    }

    func close() {
        inputPipe?.fileHandleForWriting.closeFile()
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler  = nil
        process?.terminate()
        process = nil
    }
}
