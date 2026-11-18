//
//  LocalNetworkPermission.swift
//  Flow
//
//  iOS has no API to read the Local Network permission. Browsing for our own
//  Bonjour service is the supported way to trigger the prompt, and the browser
//  reports a "policy denied" error when the user has said no.
//

import Foundation
import Network
import Combine

final class LocalNetworkPermission: ObservableObject {
    static let shared = LocalNetworkPermission()

    enum Status { case unknown, granted, denied }

    @Published private(set) var status: Status = .unknown

    private var browser: NWBrowser?
    private var timeout: DispatchWorkItem?
    private let statusKey = "flow.localNetworkStatus"

    private init() {
        switch UserDefaults.standard.string(forKey: statusKey) {
        case "granted": status = .granted
        case "denied":  status = .denied
        default:        status = .unknown
        }
    }

    /// Triggers the system prompt the first time, and refreshes `status` afterwards.
    func check() {
        browser?.cancel()
        timeout?.cancel()

        let parameters = NWParameters()
        parameters.includePeerToPeer = true
        let newBrowser = NWBrowser(for: .bonjour(type: "_flow-ctrl._tcp", domain: nil), using: parameters)
        browser = newBrowser

        newBrowser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self else { return }
                switch state {
                case .ready:
                    self.update(.granted)
                case .waiting(let error), .failed(let error):
                    if case .dns(let code) = error, code == -65570 {   // kDNSServiceErr_PolicyDenied
                        self.update(.denied)
                    }
                default:
                    break
                }
            }
        }
        newBrowser.start(queue: .main)

        let work = DispatchWorkItem { [weak self] in
            self?.browser?.cancel()
            self?.browser = nil
        }
        timeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    private func update(_ newStatus: Status) {
        guard newStatus != status else { return }
        status = newStatus
        switch newStatus {
        case .granted: UserDefaults.standard.set("granted", forKey: statusKey)
        case .denied:  UserDefaults.standard.set("denied", forKey: statusKey)
        case .unknown: UserDefaults.standard.removeObject(forKey: statusKey)
        }
    }
}
