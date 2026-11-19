//
//  DeviceAliasStore.swift
//  Flow
//
//  Custom names the user gave to their Macs. Only the label changes; the real device
//  name is still what Flow uses to find and reconnect to the Mac.
//

import Combine
import Foundation

final class DeviceAliasStore: ObservableObject {
    static let shared = DeviceAliasStore()

    @Published private(set) var aliases: [String: String]
    /// Nearby Macs the user removed from the Devices list.
    @Published private(set) var hidden: Set<String>
    private let key = "flow.deviceAliases"
    private let hiddenKey = "flow.hiddenNearbyDevices"

    private init() {
        aliases = (UserDefaults.standard.dictionary(forKey: key) as? [String: String]) ?? [:]
        hidden = Set(UserDefaults.standard.stringArray(forKey: "flow.hiddenNearbyDevices") ?? [])
    }

    func displayName(for deviceName: String) -> String {
        aliases[deviceName] ?? deviceName
    }

    func setName(_ name: String, for deviceName: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == deviceName {
            aliases.removeValue(forKey: deviceName)
        } else {
            aliases[deviceName] = String(trimmed.prefix(40))
        }
        UserDefaults.standard.set(aliases, forKey: key)
    }

    func hide(_ deviceName: String) {
        hidden.insert(deviceName)
        UserDefaults.standard.set(Array(hidden), forKey: hiddenKey)
    }

    func unhide(_ deviceName: String) {
        guard hidden.remove(deviceName) != nil else { return }
        UserDefaults.standard.set(Array(hidden), forKey: hiddenKey)
    }

    func removeName(for deviceName: String) {
        guard aliases.removeValue(forKey: deviceName) != nil else { return }
        UserDefaults.standard.set(aliases, forKey: key)
    }
}
