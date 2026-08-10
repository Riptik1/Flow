//
//  PlanTier.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//


import SwiftUI

enum PlanTier: Int, CaseIterable {
    case free, monthly, lifetime

    var title: String {
        switch self {
        case .free: return "Free"
        case .monthly: return "Monthly"
        case .lifetime: return "Lifetime"
        }
    }

    var price: String {
        switch self {
        case .free: return "$0"
        case .monthly: return "$4.99"
        case .lifetime: return "$49.99"
        }
    }

    var priceSuffix: String? {
        switch self {
        case .free: return nil
        case .monthly: return "/ month"
        case .lifetime: return "one-time"
        }
    }

    var icon: String {
        switch self {
        case .free: return "hand.tap.fill"
        case .monthly: return "bolt.fill"
        case .lifetime: return "infinity"
        }
    }

    var gradient: [Color] {
        switch self {
        case .free: return [Color(red: 0.55, green: 0.58, blue: 0.65), Color(red: 0.4, green: 0.43, blue: 0.5)]
        case .monthly: return [.blue, .purple]
        case .lifetime: return [.orange, .pink]
        }
    }

    var features: [String] {
        switch self {
        case .free:
            return [
                "Trackpad control",
                "Keyboard without Touch Bar",
                "Basic file access",
                "3 saved workflows",
                "Quick actions"
            ]
        case .monthly:
            return [
                "Everything in Free",
                "Unlimited workflows",
                "App mirroring",
                "Connect to your Mac from anywhere",
                "Use your Mac from everywhere",
                "Advanced trackpad gestures",
                "Voice commands"
            ]
        case .lifetime:
            return [
                "Everything in Monthly",
                "App mirroring",
                "Connect to your Mac from anywhere",
                "Use your Mac from everywhere",
                "All future updates included",
                "Priority support"
            ]
        }
    }

    var tierKey: String {
        switch self {
        case .free: return "none"
        case .monthly: return "monthly"
        case .lifetime: return "lifetime"
        }
    }
}
