//
//  UserDefaultsCodableStore.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Foundation

struct UserDefaultsCodableStore<Value: Codable> {
    let key: String
    let defaults: UserDefaults

    init(key: String, defaults: UserDefaults = .standard) {
        self.key = key
        self.defaults = defaults
    }

    func load() -> Value? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(Value.self, from: data)
    }

    func save(_ value: Value) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}

struct UserDefaultsStringSetStore {
    let key: String
    let defaults: UserDefaults
    let maxCount: Int

    init(key: String, maxCount: Int, defaults: UserDefaults = .standard) {
        self.key = key
        self.maxCount = maxCount
        self.defaults = defaults
    }

    func load() -> Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    func save(_ value: Set<String>) {
        defaults.set(Array(value.prefix(maxCount)), forKey: key)
    }
}
