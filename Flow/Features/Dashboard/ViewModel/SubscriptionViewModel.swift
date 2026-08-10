import SwiftUI

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
        case .free:
            subTier = "none"
            subEndDate = ""
        case .monthly:
            subTier = "monthly"
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
            subEndDate = formatter.string(from: endDate)
        case .lifetime:
            subTier = "lifetime"
            subEndDate = ""
        }
    }

    func buttonLabel(for tier: PlanTier, isCurrent: Bool) -> String {
        if isCurrent {
            return tier == .free ? "Current Plan" : (tier == .lifetime ? "Owned" : "Subscribed")
        }
        switch tier {
        case .free: return "Switch to Free"
        case .monthly: return "Subscribe"
        case .lifetime: return "Purchase"
        }
    }
}
