//
//  SubscriptionViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI
import Combine

final class SubscriptionViewModel: ObservableObject {
    @AppStorage("flow.subscriptionTier") var subTier: String = "monthly"
    @AppStorage("flow.subscriptionEndDate") var subEndDate: String = ""

    let plans = PlanTier.allCases
    let loopCount = 240

    func middleSelectionIndex() -> Int {
        let middle = (loopCount / 2) - (loopCount / 2) % PlanTier.allCases.count
        return middle + PlanTier.monthly.rawValue
    }

    func tier(atLoopIndex index: Int) -> PlanTier {
        plans[((index % plans.count) + plans.count) % plans.count]
    }

    func select(_ tier: PlanTier) {
        switch tier {
        case .weekly:
            subTier = "weekly"
            setExpiry(byAdding: .day, value: 7)
        case .monthly:
            subTier = "monthly"
            setExpiry(byAdding: .month, value: 1)
        case .lifetime:
            subTier = "lifetime"
            subEndDate = ""
        }
    }

    private func setExpiry(byAdding component: Calendar.Component, value: Int) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let endDate = Calendar.current.date(byAdding: component, value: value, to: Date())!
        subEndDate = formatter.string(from: endDate)
    }

    func buttonLabel(for tier: PlanTier, isCurrent: Bool) -> String {
        if isCurrent {
            return tier == .lifetime ? "Owned" : "Subscribed"
        }
        switch tier {
        case .weekly: return "Subscribe"
        case .monthly: return "Subscribe"
        case .lifetime: return "Purchase"
        }
    }
}
