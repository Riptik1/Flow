//
//  PremiumAccessManager.swift
//  Flow
//
//  Created by Riptik Jhajhria on 31/07/26.
//

import Foundation
import Combine

final class PremiumAccessManager: ObservableObject {
    static let shared = PremiumAccessManager()

    private let trialDurationSeconds: TimeInterval = 3 * 24 * 60 * 60
    private let keychainService = "com.flow.app.trial"
    private let keychainAccount = "trialStartDate"
    private let subscriptionDefaultsKey = "flow.subscriptionTier"

    private let trialStartDate: Date
    private var notificationObserver: NSObjectProtocol?
    private var refreshTimer: Timer?

    @Published private(set) var subscriptionTier: String

    private init() {
        if let existing = KeychainStore.readDate(service: keychainService, account: keychainAccount) {
            trialStartDate = existing
        } else {
            let now = Date()
            KeychainStore.writeDate(now, service: keychainService, account: keychainAccount)
            trialStartDate = now
        }

        subscriptionTier = UserDefaults.standard.string(forKey: subscriptionDefaultsKey) ?? "none"

        notificationObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.syncSubscriptionTier()
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    deinit {
        if let notificationObserver {
            NotificationCenter.default.removeObserver(notificationObserver)
        }
        refreshTimer?.invalidate()
    }

    private func syncSubscriptionTier() {
        let current = UserDefaults.standard.string(forKey: subscriptionDefaultsKey) ?? "none"
        if current != subscriptionTier {
            subscriptionTier = current
        }
    }

    var isSubscribed: Bool {
        subscriptionTier == "weekly" || subscriptionTier == "monthly" || subscriptionTier == "lifetime"
    }

    var trialTimeRemaining: TimeInterval {
        max(0, trialDurationSeconds - Date().timeIntervalSince(trialStartDate))
    }

    var isTrialActive: Bool {
        trialTimeRemaining > 0
    }

    var hasPremiumAccess: Bool {
        isSubscribed || isTrialActive
    }

    var trialDaysRemaining: Int {
        Int(ceil(trialTimeRemaining / 86400))
    }

    var overlayState: CardOverlayState {
        hasPremiumAccess ? .none : .premiumRequired
    }
}
