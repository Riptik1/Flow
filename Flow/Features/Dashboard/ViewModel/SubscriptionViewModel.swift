//
//  SubscriptionViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI
import Combine

/// Thin view-model over `StoreKitManager`. Nothing here grants access by itself –
/// the tier always comes from the App Store.
final class SubscriptionViewModel: ObservableObject {
    private let store = StoreKitManager.shared
    private var cancellable: AnyCancellable?

    let plans = PlanTier.allCases
    let loopCount = 240

    init() {
        cancellable = store.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
        Task { await store.loadProducts(); await store.refreshEntitlements() }
    }

    var subTier: String { store.activeTier }
    var isBusy: Bool { store.isPurchasing }
    var renewalText: String? { store.renewalDescription }
    var hasActiveSubscription: Bool { store.activeTier == "weekly" || store.activeTier == "monthly" }

    var message: String? {
        get { store.message }
        set { store.message = newValue }
    }

    func middleSelectionIndex() -> Int {
        let middle = (loopCount / 2) - (loopCount / 2) % PlanTier.allCases.count
        return middle + PlanTier.monthly.rawValue
    }

    func tier(atLoopIndex index: Int) -> PlanTier {
        plans[((index % plans.count) + plans.count) % plans.count]
    }

    func price(for tier: PlanTier) -> String {
        store.displayPrice(for: tier) ?? tier.price
    }

    func select(_ tier: PlanTier) {
        Task { await store.purchase(tier) }
    }

    func restore() {
        Task { await store.restore() }
    }

    /// Cancel, change plan or renew – all handled in Apple's own sheet.
    func manage() {
        Task { await store.manageSubscription() }
    }

    func buttonLabel(for tier: PlanTier, isCurrent: Bool) -> String {
        if isCurrent {
            return tier == .lifetime ? "Owned" : "Subscribed"
        }
        if store.activeTier == "lifetime" { return "Included" }
        switch tier {
        case .weekly: return "Subscribe"
        case .monthly: return "Subscribe"
        case .lifetime: return "Purchase"
        }
    }
}
