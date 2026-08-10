import MultipeerConnectivity
import Foundation
import Combine

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
import Darwin
import ScreenCaptureKit
#endif

enum FlowConnectionState: Equatable {
    case disconnected
    case searching
    case connecting
    case connected
}

struct DiscoveredPeer: Identifiable, Equatable {
    let id = UUID()
    let peerID: MCPeerID
    let deviceName: String
    let deviceModel: String
    let platform: String
    let batteryLevel: Float
    let userName: String
    let profileImageData: Data?
    let transport: ConnectionTransport

    init(
        peerID: MCPeerID,
        deviceName: String,
        deviceModel: String,
        platform: String,
        batteryLevel: Float,
        userName: String,
        profileImageData: Data?,
        transport: ConnectionTransport = .local
    ) {
        self.peerID = peerID
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.platform = platform
        self.batteryLevel = batteryLevel
        self.userName = userName
        self.profileImageData = profileImageData
        self.transport = transport
    }

    static func == (lhs: DiscoveredPeer, rhs: DiscoveredPeer) -> Bool {
        lhs.peerID == rhs.peerID
    }
}

@MainActor
final class ConnectionManager: NSObject, ObservableObject {
    static let shared = ConnectionManager()

    private let serviceType = "flow-ctrl"
    private let peerID: MCPeerID

    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var reconnectWork: DispatchWorkItem?
    private var connectTimeoutWork: DispatchWorkItem?
    private var pendingInvitePeerID: MCPeerID?
    private var connectedSince: Date?
    private var flakyPeerName: String?
    private var flakyCooldownUntil: Date?
    private var keepaliveTimer: Timer?

    @Published var state: FlowConnectionState = .disconnected
    @Published var discoveredPeers: [DiscoveredPeer] = []
    @Published var connectedPeer: DiscoveredPeer? = nil
    @Published var macProfileImageData: Data? = nil

    private let savedPeerKey = "flow.lastConnectedPeer"

    var savedPeerName: String? {
        get { UserDefaults.standard.string(forKey: savedPeerKey) }
        set { UserDefaults.standard.set(newValue, forKey: savedPeerKey) }
    }

    var hasStoredConnection: Bool { savedPeerName != nil }

    private var localDeviceName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #endif
    }

    private var localDeviceModel: String {
        #if canImport(UIKit)
        return UIDevice.current.model
        #else
        return resolvedMacModel()
        #endif
    }

    private var localPlatform: String {
        #if canImport(UIKit)
        return "iPhone"
        #else
        return "Mac"
        #endif
    }

    private var localBattery: String {
        #if canImport(UIKit)
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        return level < 0 ? "-1" : String(format: "%.0f", level * 100)
        #else
        return "-1"
        #endif
    }

    private var localUserName: String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return NSFullUserName()
        #endif
    }

    private let messageSubject = PassthroughSubject<FlowMessage, Never>()

    var messageStream: AnyPublisher<FlowMessage, Never> {
        messageSubject.eraseToAnyPublisher()
    }

    override init() {
        #if canImport(UIKit)
        let name = UIDevice.current.name
        #else
        let name = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
        #endif
        self.peerID = MCPeerID(displayName: name)
        super.init()
        setupSession()
    }

    private func setupSession() {
        let s = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .required)
        s.delegate = self
        session = s
    }

    func startAutoConnect() {
        guard state == .disconnected else { return }
        startBrowsingCore()
    }

    func startSearching() {
        guard state == .disconnected else { return }
        cancelReconnect()
        startBrowsingCore()
    }

    func cancelSearching() {
        cancelReconnect()
        cancelConnectTimeout()
        pendingInvitePeerID = nil
        teardownBrowsing()
        DispatchQueue.main.async { self.state = .disconnected }
    }

    func stopSearching() {
        cancelReconnect()
        teardownBrowsing()
    }

    func handleAppForeground() {
        if state == .disconnected {
            startBrowsingCore()
        }
    }

    private func startBrowsingCore() {
        teardownBrowsing()

        let info: [String: String] = [
            "name":     localDeviceName,
            "model":    localDeviceModel,
            "platform": localPlatform,
            "battery":  localBattery,
            "userName": localUserName
        ]

        let adv = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: info, serviceType: serviceType)
        adv.delegate = self
        adv.startAdvertisingPeer()
        advertiser = adv

        let brw = MCNearbyServiceBrowser(peer: peerID, serviceType: serviceType)
        brw.delegate = self
        brw.startBrowsingForPeers()
        browser = brw

        DispatchQueue.main.async {
            self.state = .searching
            self.discoveredPeers = []
        }
    }

    private func teardownBrowsing() {
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
    }

    private func cancelReconnect() {
        reconnectWork?.cancel()
        reconnectWork = nil
    }

    private func scheduleReconnect(after delay: Double = 3.0) {
        cancelReconnect()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.state == .disconnected else { return }
            self.setupSession()
            self.startBrowsingCore()
        }
        reconnectWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func startKeepalive() {
        stopKeepalive()
        keepaliveTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.state == .connected else { return }
                self.send(.requestSystemStats)
            }
        }
    }

    private func stopKeepalive() {
        keepaliveTimer?.invalidate()
        keepaliveTimer = nil
    }

    func connect(to peer: DiscoveredPeer) {
        guard let session else { return }
        pendingInvitePeerID = peer.peerID
        DispatchQueue.main.async { self.state = .connecting }
        browser?.invitePeer(peer.peerID, to: session, withContext: nil, timeout: 30)
        scheduleConnectTimeout(for: peer.peerID)
    }

    private func scheduleConnectTimeout(for peerID: MCPeerID) {
        connectTimeoutWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.pendingInvitePeerID == peerID, self.state == .connecting else { return }
            print("[Flow][Local] connect timeout: invite to \(peerID.displayName) never resolved, resuming search")
            self.pendingInvitePeerID = nil
            self.session?.disconnect()
            self.setupSession()
            self.startBrowsingCore()
        }
        connectTimeoutWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
    }

    private func cancelConnectTimeout() {
        connectTimeoutWork?.cancel()
        connectTimeoutWork = nil
    }

    func recoverFromSystemWake() {
        print("[Flow][Local] recoverFromSystemWake: forcing clean session rebuild")
        stopKeepalive()
        cancelConnectTimeout()
        pendingInvitePeerID = nil
        cancelReconnect()
        session?.disconnect()
        teardownBrowsing()
        setupSession()
        connectedPeer = nil
        discoveredPeers = []
        macProfileImageData = nil
        state = .disconnected
        #if canImport(AppKit)
        MacUnlockService.shared.stopMonitoring()
        #endif
        startBrowsingCore()
    }

    func disconnect() {
        stopKeepalive()
        cancelConnectTimeout()
        pendingInvitePeerID = nil
        session?.disconnect()
        savedPeerName = nil
        cancelReconnect()
        teardownBrowsing()
        #if canImport(AppKit)
        MacUnlockService.shared.stopMonitoring()
        #endif
        DispatchQueue.main.async {
            self.connectedPeer = nil
            self.discoveredPeers = []
            self.macProfileImageData = nil
            self.state = .disconnected
        }
    }

    func send(_ message: FlowMessage) {
        guard let session = session, let peer = connectedPeer else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [peer.peerID], with: .reliable)
        } catch {}
    }

    func sendUnreliable(_ message: FlowMessage) {
        guard let session = session, let peer = connectedPeer else { return }
        do {
            let data = try JSONEncoder().encode(message)
            try session.send(data, toPeers: [peer.peerID], with: .unreliable)
        } catch {}
    }

    private func autoConnectIfSaved(_ peer: DiscoveredPeer) {
        guard let saved = savedPeerName, peer.deviceName == saved else { return }
        if peer.deviceName == flakyPeerName, let until = flakyCooldownUntil, Date() < until {
            print("[Flow][Local] autoConnectIfSaved: \(peer.deviceName) is in flaky cooldown until \(until), skipping auto-invite so remote can take over")
            return
        }
        #if canImport(UIKit)
        connect(to: peer)
        #endif
    }

    #if canImport(UIKit)
    private func requestInitialStateFromMac() {
        let delays: [Double] = [0.5, 1.5, 3.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.state == .connected else { return }
                self.send(.requestMacUserProfile)
            }
        }
    }
    #endif

    #if canImport(AppKit)
    private func resolvedMacModel() -> String {
        var size = 0
        let result1 = sysctlbyname("hw.model", nil, &size, nil, 0)
        guard result1 == 0, size > 0 else { return "Mac" }
        var buffer = [CChar](repeating: 0, count: size)
        let result2 = sysctlbyname("hw.model", &buffer, &size, nil, 0)
        guard result2 == 0 else { return "Mac" }
        let id = String(cString: buffer)
        if id.contains("MacBookPro") { return "MacBook Pro" }
        if id.contains("MacBookAir") { return "MacBook Air" }
        if id.contains("MacBook")    { return "MacBook" }
        if id.contains("MacMini")    { return "Mac mini" }
        if id.contains("MacPro")     { return "Mac Pro" }
        if id.contains("iMac")       { return "iMac" }
        return "Mac"
    }
    #endif
}

extension ConnectionManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async {
            switch state {
            case .connected:
                let peer = self.discoveredPeers.first(where: { $0.peerID == peerID })
                    ?? DiscoveredPeer(
                        peerID: peerID,
                        deviceName: peerID.displayName,
                        deviceModel: "Mac",
                        platform: "Mac",
                        batteryLevel: -1,
                        userName: peerID.displayName,
                        profileImageData: nil
                    )
                self.cancelReconnect()
                self.cancelConnectTimeout()
                self.pendingInvitePeerID = nil
                self.connectedPeer = peer
                self.savedPeerName = peer.deviceName
                self.state = .connected
                self.connectedSince = Date()
                self.teardownBrowsing()
                self.startKeepalive()

                #if canImport(AppKit)
                MacUnlockService.shared.stopMonitoring()
                MacUnlockService.shared.startMonitoring { [weak self] message in
                    self?.send(message)
                }
                #endif

                #if canImport(UIKit)
                self.requestInitialStateFromMac()
                #endif

            case .notConnected:
                let wasConnectedPeer = self.connectedPeer?.peerID == peerID
                let wasPendingInvite = self.pendingInvitePeerID == peerID
                guard wasConnectedPeer || wasPendingInvite else { return }

                if wasConnectedPeer, let since = self.connectedSince, Date().timeIntervalSince(since) < 8.0 {
                    print("[Flow][Local] notConnected: \(peerID.displayName) dropped \(Date().timeIntervalSince(since))s after connecting, treating as flaky and backing off auto-invite for 45s")
                    self.flakyPeerName = peerID.displayName
                    self.flakyCooldownUntil = Date().addingTimeInterval(45)
                }
                self.connectedSince = nil

                self.pendingInvitePeerID = nil
                self.cancelConnectTimeout()
                self.stopKeepalive()
                self.connectedPeer = nil
                self.macProfileImageData = nil
                self.state = .disconnected

                #if canImport(AppKit)
                MacUnlockService.shared.stopMonitoring()
                #endif

                self.scheduleReconnect()

            case .connecting:
                self.state = .connecting

            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(FlowMessage.self, from: data) else { return }

        #if canImport(AppKit)
        let sendReply: (FlowMessage) -> Void = { reply in
            let mode: MCSessionSendDataMode
            switch reply {
            case .appMirroringFrame:
                mode = .unreliable
            default:
                mode = .reliable
            }
            do {
                let replyData = try JSONEncoder().encode(reply)
                try session.send(replyData, toPeers: [peerID], with: mode)
            } catch {}
        }

        AppLaunchService.shared.handle(message, reply: sendReply)
        ClipboardService.shared.handle(message) { sendReply($0) }
        FileService.shared.handle(message) { sendReply($0) }
        TerminalService.shared.handle(message, reply: sendReply)
        MacUnlockService.shared.handle(message, reply: sendReply)
        AppMirroringService.shared.handle(message, reply: sendReply)
        #else
        switch message {
        case .appMirroringFrame:
            messageSubject.send(message)

        case .macUserProfile(let imageData):
            DispatchQueue.main.async {
                self.macProfileImageData = imageData
            }

        case .systemStats:
            break

        default:
            DispatchQueue.main.async {
                self.messageSubject.send(message)
            }
        }
        #endif
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension ConnectionManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let platform = info?["platform"] ?? ""

        #if canImport(UIKit)
        guard platform == "Mac" else { return }
        #else
        guard platform == "iPhone" || platform == "iPad" else { return }
        #endif

        let peer = DiscoveredPeer(
            peerID: peerID,
            deviceName: info?["name"]    ?? peerID.displayName,
            deviceModel: info?["model"]  ?? platform,
            platform: platform,
            batteryLevel: Float(info?["battery"] ?? "-1") ?? -1,
            userName: info?["userName"]  ?? peerID.displayName,
            profileImageData: nil
        )

        DispatchQueue.main.async {
            guard !self.discoveredPeers.contains(where: { $0.peerID == peerID }) else { return }
            self.discoveredPeers.append(peer)
            self.autoConnectIfSaved(peer)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.peerID == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.state = .disconnected
            self.scheduleReconnect(after: 5.0)
        }
    }
}

extension ConnectionManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(
        _ advertiser: MCNearbyServiceAdvertiser,
        didReceiveInvitationFromPeer peerID: MCPeerID,
        withContext context: Data?,
        invitationHandler: @escaping (Bool, MCSession?) -> Void
    ) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        DispatchQueue.main.async {
            self.state = .disconnected
            self.scheduleReconnect(after: 5.0)
        }
    }
}
