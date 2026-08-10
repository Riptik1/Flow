//
//  BackTapKind.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//


import Foundation

enum BackTapKind: String, Codable, CaseIterable {
    case doubleTap = "Double Tap"
    case tripleTap = "Triple Tap"
    case quadTap   = "Four Taps"
}

struct AppWorkflow: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var name: String
    var iconName: String
    var iconColorHex: String
    var appBundleIDs: [String]
    var backTapEnabled: Bool = false
    var backTapKind: BackTapKind = .doubleTap

    static func == (lhs: AppWorkflow, rhs: AppWorkflow) -> Bool { lhs.id == rhs.id }
}

enum WorkflowIconCatalog {
    static let icons: [(symbol: String, label: String)] = [
        ("chevron.left.forwardslash.chevron.right", "Code"),
        ("terminal.fill",        "Terminal"),
        ("hammer.fill",          "Build"),
        ("briefcase.fill",       "Work"),
        ("paintbrush.fill",      "Design"),
        ("wand.and.stars",       "Magic"),
        ("music.note",           "Music"),
        ("video.fill",           "Video"),
        ("mic.fill",             "Record"),
        ("gamecontroller.fill",  "Gaming"),
        ("book.fill",            "Study"),
        ("graduationcap.fill",   "Learn"),
        ("heart.fill",           "Health"),
        ("dumbbell.fill",        "Workout"),
        ("bolt.fill",            "Focus"),
        ("folder.fill",          "Files"),
        ("envelope.fill",        "Mail"),
        ("calendar",             "Calendar"),
        ("camera.fill",          "Camera"),
        ("photo.fill",           "Photo"),
        ("chart.bar.fill",       "Stats"),
        ("dollarsign.circle.fill", "Money"),
        ("globe",                "Web"),
        ("star.fill",            "Fave"),
        ("flame.fill",           "Hot"),
        ("lock.fill",            "Secure"),
        ("sparkles",             "AI"),
        ("cpu.fill",             "Dev"),
        ("headphones",           "Listen"),
        ("moon.fill",            "Night")
    ]

    static let colorPairs: [(top: String, bottom: String)] = [
        ("7D32F5", "5B10C4"),
        ("3B82F6", "1D4ED8"),
        ("EC4899", "BE185D"),
        ("10B981", "059669"),
        ("F97316", "EA580C"),
        ("EF4444", "DC2626"),
        ("06B6D4", "0891B2"),
        ("F59E0B", "D97706"),
        ("8B5CF6", "7C3AED"),
        ("14B8A6", "0D9488")
    ]
}
