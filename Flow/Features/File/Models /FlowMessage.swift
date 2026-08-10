import Foundation

enum SwipeDirection: Int, Codable {
    case left = 0
    case right = 1
    case up = 2
    case down = 3
}

struct TouchBarTab: Codable, Identifiable {
    let id: UUID
    let title: String
    let url: String
    let isActive: Bool
}

struct XcodeRecentFile: Codable, Identifiable {
    let id: UUID
    let name: String
    let path: String
    let ext: String
}

struct MacApp: Codable, Identifiable {
    let id: UUID
    let name: String
    let bundleID: String
    let path: String
    let category: String
}

struct MacAppIcon: Codable {
    let bundleID: String
    let pngData: Data
}

struct RunningApp: Codable, Identifiable {
    let id: UUID
    let bundleID: String
    let name: String
    let iconPNG: Data?
    let isActive: Bool
}

struct RecentProject: Codable, Identifiable {
    let id: UUID
    let name: String
    let path: String
}

struct RawLogEntry: Codable {
    let level: String
    let process: String
    let message: String
    let timestamp: TimeInterval
}

struct RawSystemStats: Codable {
    let cpuPercent: Double
    let coreCount: Int
    let memUsedGB: Double
    let memTotalGB: Double
    let diskUsedGB: Double
    let diskTotalGB: Double
    let netUpMBps: String
    let netDownMBps: String
}

struct SpotlightResult: Codable, Identifiable {
    let id: UUID
    let name: String
    let path: String
    let kind: String
    let iconPNG: Data?
}

enum TouchBarActionKind: Codable {
    case brightnessUp
    case brightnessDown
    case volumeUp
    case volumeDown
    case mute
    case mediaPlay
    case mediaPrev
    case mediaNext
    case sleep
    case lockScreen
    case doNotDisturb
    case switchBrowserTab(index: Int)
    case browserBack
    case browserForward
    case newBrowserTab
    case closeBrowserTab
    case reopenClosedTab
    case openXcodeFile(index: Int)
    case missionControl
    case appWindows
    case launchpad
    case showDesktop
    case spotlight
    case keyboardBrightnessUp
    case keyboardBrightnessDown
}

enum ClipboardContentType: String, Codable {
    case code
    case text
    case url
    case image
    case json
    case markdown
    case sql
    case other
}

struct ClipboardItem: Codable, Identifiable {
    let id: UUID
    let contentType: ClipboardContentType
    let text: String?
    let imageData: Data?
    let timestamp: TimeInterval
}

enum FlowMessage: Codable {
    case checkPermissions
    case permissionStatus(granted: Bool, missing: [String])
    case listDirectory(path: String)
    case directoryContents(files: [RemoteFileItem])
    case getRecents
    case recentFiles(files: [RemoteFileItem])
    case previewFile(path: String)
    case filePreview(data: Data, uti: String)
    case shareFile(path: String)
    case shareData(data: Data, uti: String)
    case saveFileToDevice(path: String)
    case saveFileData(data: Data, uti: String)
    case moveItem(from: String, to: String)
    case copyItem(from: String, to: String)
    case deleteItem(path: String)
    case operationSuccess
    case operationFailure(error: String)
    case mouseMove(dx: Float, dy: Float)
    case leftClick
    case rightClick
    case doubleClick
    case scrollBegan
    case scroll(dx: Float, dy: Float)
    case scrollEnded
    case magnifyBegan
    case magnify(delta: Float)
    case magnifyEnded
    case smartZoom
    case swipe(direction: SwipeDirection, fingers: Int)
    case clickDragBegin
    case clickDragMove(dx: Float, dy: Float)
    case clickDragEnd
    case threeFingerDragBegin
    case threeFingerDragMove(dx: Float, dy: Float)
    case threeFingerDragEnd
    case keyPress(keyCode: Int, modifiers: Int)
    case typeText(text: String)
    case touchBarStateRequest
    case touchBarAppState(bundleID: String, appName: String)
    case touchBarBrowserTabs(tabs: [TouchBarTab])
    case touchBarXcodeFiles(files: [XcodeRecentFile])
    case touchBarAction(kind: TouchBarActionKind)
    case requestAppList
    case appList(apps: [MacApp])
    case appIconChunk(icons: [MacAppIcon])
    case launchApp(bundleID: String)
    case terminalInput(sessionID: String, command: String)
    case terminalOutput(sessionID: String, text: String)
    case terminalError(sessionID: String, text: String)
    case terminalNewSession(sessionID: String)
    case terminalCloseSession(sessionID: String)
    case requestEnvironment
    case environmentData(entries: [String: String])
    case requestSystemStats
    case systemStats(stats: RawSystemStats)
    case startLogStream
    case stopLogStream
    case logEntry(entry: RawLogEntry)
    case spotlightSearch(query: String)
    case spotlightResults(results: [SpotlightResult])
    case spotlightOpen(path: String)
    case muteAudio
    case unmuteAudio
    case muteStateChanged(isMuted: Bool)
    case systemLockScreen
    case systemShutDown
    case systemShutDownForce
    case systemShutDownBlocked(blockedBy: [String])
    case systemRestart
    case requestClipboardHistory
    case clipboardHistory(items: [ClipboardItem])
    case clipboardDidChange(item: ClipboardItem)
    case pasteClipboardItem(id: UUID)
    case setRemoteClipboardText(text: String)
    case setRemoteClipboardAndPaste(text: String)
    case requestRunningApps
    case runningApps(apps: [RunningApp])
    case quitApp(bundleID: String, force: Bool)
    case appQuitSuccess
    case appQuitFailure(error: String)
    case requestAppRecentProjects(bundleID: String)
    case appRecentProjects(bundleID: String, projects: [RecentProject])
    case openProject(path: String)
    case requestRecentFiles(limit: Int)
    case activateApp(bundleID: String)
    case unlockMac(password: String)
    case unlockSuccess
    case unlockFailed
    case macLockedState(locked: Bool)
    case requestMacUserProfile
    case macUserProfile(imageData: Data)
    case wakeMac
    case startAppMirroring(bundleID: String)
    case stopAppMirroring
    case appMirroringConfig(width: Int, height: Int, frameRate: Int, port: UInt16, host: String)
    case appMirroringFrame(data: Data, timestamp: TimeInterval)
    case appMirroringInputTouch(phase: Int, x: Float, y: Float)
    case appMirroringInputClick(x: Float, y: Float)
    case appMirroringInputScroll(dx: Float, dy: Float)
    case appMirroringInputKey(keyCode: Int, modifiers: Int, pressed: Bool)
    case appMirroringInputRightClick(x: Float, y: Float)
    case appMirroringInputDoubleClick(x: Float, y: Float)
    case appMirroringInputText(text: String)
    case appMirroringStarted
    case appMirroringStopped
    case appMirroringError(error: String)
    case remoteHandshake(deviceID: UUID)
    case remoteHandshakeAck(deviceID: UUID)
    case appMirroringRemoteOffer(sdp: String)
    case appMirroringRemoteAnswer(sdp: String)
    case appMirroringRemoteCandidate(sdp: String, sdpMLineIndex: Int32, sdpMid: String)
    case appMirroringRemoteEnd
}

struct RemoteFileItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let path: String
    let dateModified: TimeInterval
    let size: Int64?
    let isDirectory: Bool
    let uti: String
}
