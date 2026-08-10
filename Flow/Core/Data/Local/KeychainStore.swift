//
//  KeychainStore.swift
//  Flow
//
//  Created by Riptik Jhajhria on 31/07/26.
//

import Foundation
import Security

enum KeychainStore {
    static func writeDate(_ date: Date, service: String, account: String) {
        let interval = date.timeIntervalSince1970
        let data = withUnsafeBytes(of: interval) { Data($0) }
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(baseQuery as CFDictionary)
        var attributes = baseQuery
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func readDate(service: String, account: String) -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              data.count == MemoryLayout<TimeInterval>.size else {
            return nil
        }
        let interval = data.withUnsafeBytes { $0.load(as: TimeInterval.self) }
        return Date(timeIntervalSince1970: interval)
    }
}
