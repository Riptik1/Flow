//
//  FlowDeviceIdentity.swift
//  Flow
//
//  Created by Riptik Jhajhria on 14/07/26.
//


//
//  FlowDeviceIdentity.swift
//  Flow
//
//  Created by Riptik Jhajhria on 13/07/26.
//

import Foundation

@MainActor
final class FlowDeviceIdentity {
    static let shared = FlowDeviceIdentity()

    private let linkIDKey = "flow.remote.lastDeviceLinkID"
    private let macNameKey = "flow.remote.lastMacName"
    private let macModelKey = "flow.remote.lastMacModel"

    private init() {}

    var lastDeviceLinkID: UUID? {
        get { UserDefaults.standard.string(forKey: linkIDKey).flatMap(UUID.init) }
        set { UserDefaults.standard.set(newValue?.uuidString, forKey: linkIDKey) }
    }

    var lastKnownMac: (name: String, model: String)? {
        get {
            guard let name = UserDefaults.standard.string(forKey: macNameKey),
                  let model = UserDefaults.standard.string(forKey: macModelKey)
            else { return nil }
            return (name, model)
        }
        set {
            UserDefaults.standard.set(newValue?.name, forKey: macNameKey)
            UserDefaults.standard.set(newValue?.model, forKey: macModelKey)
        }
    }

    func remember(linkID: UUID, macName: String, macModel: String) {
        lastDeviceLinkID = linkID
        lastKnownMac = (macName, macModel)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: linkIDKey)
        UserDefaults.standard.removeObject(forKey: macNameKey)
        UserDefaults.standard.removeObject(forKey: macModelKey)
    }
}