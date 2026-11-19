//
//  PlanTier.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI

enum PlanTier: Int, CaseIterable {
    case weekly
    case monthly
    case lifetime

    var tierKey: String {
        switch self {
        case .weekly: return "weekly"
        case .monthly: return "monthly"
        case .lifetime: return "lifetime"
        }
    }

    var productID: String {
        switch self {
        case .weekly: return StoreKitManager.ProductID.weekly
        case .monthly: return StoreKitManager.ProductID.monthly
        case .lifetime: return StoreKitManager.ProductID.lifetime
        }
    }

    var title: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        }
    }

    var price: String {
        switch self {
        case .weekly: return "$49"
        case .monthly: return "$149"
        case .lifetime: return "$399"
        }
    }

    var priceSuffix: String? {
        switch self {
        case .weekly: return "per week"
        case .monthly: return "per month"
        case .lifetime: return "one-time"
        }
    }

    var icon: String {
        switch self {
        case .weekly: return "bolt.fill"
        case .monthly: return "star.fill"
        case .lifetime: return "infinity"
        }
    }

    var gradient: [Color] {
        switch self {
        case .weekly: return [Color.blue, Color.cyan]
        case .monthly: return [Color.purple, Color.pink]
        case .lifetime: return [Color.orange, Color.yellow]
        }
    }

    var features: [String] {
        [
            "Remotely use Mac apps on your device",
            "Remote file access",
            "Full terminal access",
            "Touch Bar in your keyboard",
            "Workflows and back-tap shortcuts",
            "Search your Mac from your iPhone"
        ]
    }
}
