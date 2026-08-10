//
//  SidebarItem.swift
//  Flow
//
//  Created by Riptik Jhajhria on 03/07/26.
//

import Foundation

enum SidebarItemType: String, Hashable {
    case recents, shared
    case applications, desktop, documents, downloads
    case iCloudDrive, home, macintoshHD, airDrop
}

struct SidebarItem: Identifiable, Hashable {
    let id: SidebarItemType
    let title: String
    let systemImage: String

    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let recents      = SidebarItem(id: .recents,      title: "Recents",       systemImage: "clock")
    static let shared       = SidebarItem(id: .shared,       title: "Shared",        systemImage: "person.2")
    static let applications = SidebarItem(id: .applications, title: "Applications",  systemImage: "square.grid.2x2")
    static let desktop      = SidebarItem(id: .desktop,      title: "Desktop",       systemImage: "desktopcomputer")
    static let documents    = SidebarItem(id: .documents,    title: "Documents",     systemImage: "doc.richtext.fill")
    static let downloads    = SidebarItem(id: .downloads,    title: "Downloads",     systemImage: "arrow.down.circle")
    static let iCloudDrive  = SidebarItem(id: .iCloudDrive,  title: "iCloud Drive",  systemImage: "icloud")
    static let home         = SidebarItem(id: .home,         title: "Home",          systemImage: "house")
    static let macintoshHD  = SidebarItem(id: .macintoshHD,  title: "Macintosh HD",  systemImage: "internaldrive")
    static let airDrop      = SidebarItem(id: .airDrop,      title: "AirDrop",       systemImage: "wifi")
}

struct SidebarSection: Identifiable {
    let id: String
    let title: String?
    let items: [SidebarItem]

    static let all: [SidebarSection] = [
        SidebarSection(id: "main",       title: nil,          items: [.recents, .shared]),
        SidebarSection(id: "favourites", title: "Favourites", items: [.applications, .desktop, .documents, .downloads]),
        SidebarSection(id: "locations",  title: "Locations",  items: [.iCloudDrive, .home, .macintoshHD, .airDrop])
    ]
}
