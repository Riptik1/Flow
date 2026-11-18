//
//  StoreKitManager.swift
//  Flow
//
//  StoreKit 2 subscriptions – no backend. The App Store is the source of truth:
//  entitlements are re-read from `Transaction.currentEntitlements` at launch and
//  whenever a transaction update arrives (renewal, cancellation, refund, restore,
//  purchase on another device). The tier is mirrored into UserDefaults only so
//  the UI has a value before StoreKit answers.
//

import Foundation
import Combine
import StoreKit
import UIKit

final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    enum ProductID {
        static let weekly   = "com.flow.week"
        static let monthly  = "com.flow.month"
        static let lifetime = "com.flow.lifetime"
        static let all = [weekly, monthly, lifetime]
    }

    static let tierKey = "flow.subscriptionTier"
    static let endDateKey = "flow.subscriptionEndDate"

    @Published private(set) var products: [String: Product] = [:]
    @Published private(set) var activeTier: String
    @Published private(set) var expirationDate: Date?
    @Published private(set) var willAutoRenew = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var message: String?

    private var updatesTask: Task<Void, Never>?
    private var started = false

    private init() {
        activeTier = UserDefaults.standard.string(forKey: Self.tierKey) ?? "none"
    }

    deinit { updatesTask?.cancel() }

    /// Call once at launch.
    func start() {
        guard !started else { return }
        started = true
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    // MARK: - Products

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let fetched = try await Product.products(for: ProductID.all)
            products = Dictionary(uniqueKeysWithValues: fetched.map { ($0.id, $0) })
            if fetched.isEmpty {
                flowLog("[Flow][Store] no products returned – check the product IDs in App Store Connect")
            }
        } catch {
            flowLog("[Flow][Store] loadProducts failed: \(error)")
        }
    }

    func displayPrice(for tier: PlanTier) -> String? {
        products[tier.productID]?.displayPrice
    }

    // MARK: - Purchase / restore / manage

    func purchase(_ tier: PlanTier) async {
        if products[tier.productID] == nil { await loadProducts() }
        guard let product = products[tier.productID] else {
            message = "This plan isn't available right now. Check your connection and try again."
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                case .unverified:
                    message = "Purchase couldn't be verified."
                }
            case .userCancelled:
                break
            case .pending:
                message = "Waiting for approval."
            @unknown default:
                break
            }
        } catch {
            message = error.localizedDescription
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            message = activeTier == "none" ? "No purchases to restore." : "Purchases restored."
        } catch {
            message = "Couldn't restore purchases: \(error.localizedDescription)"
        }
    }

    /// Opens Apple's subscription sheet, where the user can cancel, change or renew.
    func manageSubscription() async {
        guard let scene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene else { return }
        do {
            try await AppStore.showManageSubscriptions(in: scene)
        } catch {
            if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                await UIApplication.shared.open(url)
            }
        }
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    func refreshEntitlements() async {
        var bestRank = 0
        var bestTier = "none"
        var bestExpiry: Date?
        var bestProductID: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result, transaction.revocationDate == nil else { continue }
            let rank: Int
            let tier: String
            switch transaction.productID {
            case ProductID.lifetime: rank = 3; tier = "lifetime"
            case ProductID.monthly:  rank = 2; tier = "monthly"
            case ProductID.weekly:   rank = 1; tier = "weekly"
            default: continue
            }
            if let expiry = transaction.expirationDate, expiry < Date() { continue }
            if rank > bestRank {
                bestRank = rank
                bestTier = tier
                bestExpiry = transaction.expirationDate
                bestProductID = transaction.productID
            }
        }

        var renews = false
        if let bestProductID, bestTier != "lifetime", let product = products[bestProductID],
           let status = try? await product.subscription?.status.first,
           case .verified(let info) = status.renewalInfo {
            renews = info.willAutoRenew
        }

        activeTier = bestTier
        expirationDate = bestExpiry
        willAutoRenew = renews

        let defaults = UserDefaults.standard
        defaults.set(bestTier, forKey: Self.tierKey)
        if let bestExpiry {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            defaults.set(formatter.string(from: bestExpiry), forKey: Self.endDateKey)
        } else {
            defaults.set("", forKey: Self.endDateKey)
        }
    }

    /// "Renews on …" / "Expires on …" for the active subscription, nil for lifetime or none.
    var renewalDescription: String? {
        guard let expirationDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let date = formatter.string(from: expirationDate)
        return willAutoRenew ? "Renews on \(date)" : "Ends on \(date)"
    }
}
