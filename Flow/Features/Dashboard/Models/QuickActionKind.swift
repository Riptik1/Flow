//
//  QuickActionKind.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI

enum QuickActionKind: Hashable {
    case launchApp
    case workflows
    case terminal
    case clipboard
    case search
    case muteMac
    case lockMac
    case shutDown
}

struct QuickAction: Identifiable {
    let id: QuickActionKind
    let title: String
    let icon: String
    let topColor: Color
    let bottomColor: Color
    let kind: QuickActionKind
}
