//
//  LaunchAppService.swift
//  Flow Mac-Mirrioring
//
//  Created by Riptik Jhajhria on 30/05/26.
//

import AppKit
import Foundation

final class AppLaunchService {
    static let shared = AppLaunchService()

    private let iconSize: CGFloat = 64
    private let chunkSize: Int = 1

    private let allowedCategories: Set<String> = [
        "public.app-category.developer-tools",
        "public.app-category.productivity",
        "public.app-category.utilities",
        "public.app-category.graphics-design",
        "public.app-category.video",
        "public.app-category.music",
        "public.app-category.photography",
        "public.app-category.social-networking",
        "public.app-category.news",
        "public.app-category.reference",
        "public.app-category.education",
        "public.app-category.games",
        "public.app-category.entertainment",
        "public.app-category.finance",
        "public.app-category.healthcare-fitness",
        "public.app-category.business",
        "public.app-category.lifestyle",
        "public.app-category.travel",
        "public.app-category.sports",
        "public.app-category.weather",
        "public.app-category.books",
        "public.app-category.navigation",
        "public.app-category.food-drink",
        "public.app-category.shopping"
    ]

    private let knownAppleBundleIDs: Set<String> = [
        "com.apple.Safari",
        "com.apple.mail",
        "com.apple.Notes",
        "com.apple.reminders",
        "com.apple.iCal",
        "com.apple.AddressBook",
        "com.apple.Photos",
        "com.apple.Music",
        "com.apple.TV",
        "com.apple.podcasts",
        "com.apple.news",
        "com.apple.stocks",
        "com.apple.Maps",
        "com.apple.FaceTime",
        "com.apple.MobileSMS",
        "com.apple.VoiceMemos",
        "com.apple.Home",
        "com.apple.findmy",
        "com.apple.shortcuts",
        "com.apple.Preview",
        "com.apple.TextEdit",
        "com.apple.calculator",
        "com.apple.Dictionary",
        "com.apple.FontBook",
        "com.apple.Stickies",
        "com.apple.systempreferences",
        "com.apple.AppStore",
        "com.apple.dt.Xcode",
        "com.apple.iphonesimulator",
        "com.apple.Terminal",
        "com.apple.ActivityMonitor",
        "com.apple.DiskUtility",
        "com.apple.Console",
        "com.apple.ScreenSaver.Engine",
        "com.apple.Screenshot",
        "com.apple.Image_Capture",
        "com.apple.automator",
        "com.apple.ScriptEditor2",
        "com.apple.ColorSync",
        "com.apple.grapher",
        "com.apple.chess",
        "com.apple.iWork.Pages",
        "com.apple.iWork.Numbers",
        "com.apple.iWork.Keynote",
        "com.apple.iMovie",
        "com.apple.GarageBand",
        "com.apple.logic10",
        "com.apple.finalcutpro",
        "com.apple.dt.instruments",
        "com.apple.Xcode",
        "com.apple.QuickTimePlayerX",
        "com.apple.DigitalColorMeter",
        "com.apple.Accessibility-Inspector",
        "com.apple.MakeMKV"
    ]

    private let blockedBundleIDPrefixes: [String] = [
        "com.apple.preference.",
        "com.apple.WebKit",
        "com.apple.webkit",
        "com.apple.SafariServices",
        "com.apple.appkit",
        "com.apple.coreservices",
        "com.apple.CoreServices",
        "com.apple.security",
        "com.apple.framework",
        "com.apple.audio",
        "com.apple.bluetooth",
        "com.apple.AirPort",
        "com.apple.airport",
        "com.apple.wifi",
        "com.apple.avb",
        "com.apple.AVBAgent",
        "com.apple.NetworkDiagnostics"
    ]

    private let blockedNamePatterns: [String] = [
        "Agent", "Helper", "Daemon", "Service", "Plugin", "XPC",
        "Background", "Extension", "Framework", "Server", "UI Server",
        "UIServer", "Configuration", "Manager", "Updater", "Installer",
        "Uninstaller", "Launcher", "Injector", "Notifier", "Watcher",
        "Monitor Helper", "Renderer", "GPU", "WebContent"
    ]

    private init() {}

    func installedApps() -> [MacApp] {
        var seen  = Set<String>()
        var apps: [MacApp] = []

        let searchDirs = ["/Applications", NSString("~/Applications").expandingTildeInPath]

        for dir in searchDirs {
            collectApps(in: dir, seen: &seen, apps: &apps)
        }

        for bundleID in knownAppleBundleIDs {
            guard !seen.contains(bundleID) else { continue }
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
                  let bundle = Bundle(url: url),
                  let name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                              ?? (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            else { continue }
            seen.insert(bundleID)
            apps.append(MacApp(id: UUID(), name: name, bundleID: bundleID, path: url.path, category: ""))
        }

        return apps
            .filter { isRelevantApp($0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func collectApps(in dir: String, seen: inout Set<String>, apps: inout [MacApp]) {
        let url = URL(fileURLWithPath: dir)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url, includingPropertiesForKeys: [.isApplicationKey], options: [.skipsHiddenFiles]
        ) else { return }

        for appURL in contents {
            if appURL.pathExtension == "app" {
                if let bundle = Bundle(url: appURL), let bundleID = bundle.bundleIdentifier, !seen.contains(bundleID) {
                    seen.insert(bundleID)
                    let name = (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                               ?? (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                               ?? appURL.deletingPathExtension().lastPathComponent
                    let category = bundle.object(forInfoDictionaryKey: "LSApplicationCategoryType") as? String ?? ""
                    apps.append(MacApp(id: UUID(), name: name, bundleID: bundleID, path: appURL.path, category: category))
                }
            } else if appURL.hasDirectoryPath {
                collectApps(in: appURL.path, seen: &seen, apps: &apps)
            }
        }
    }

    private func isRelevantApp(_ app: MacApp) -> Bool {
        let bundleID = app.bundleID
        let name     = app.name

        if knownAppleBundleIDs.contains(bundleID) { return true }

        for prefix in blockedBundleIDPrefixes {
            if bundleID.lowercased().hasPrefix(prefix.lowercased()) { return false }
        }

        for pattern in blockedNamePatterns {
            if name.contains(pattern) { return false }
        }

        if name.hasSuffix(" Helper") || name.hasSuffix(" Agent") || name.hasSuffix("Helper (GPU)")
            || name.hasSuffix("Helper (Plugin)") || name.hasSuffix("Helper (Renderer)") { return false }

        if !app.category.isEmpty && !allowedCategories.contains(app.category) { return false }

        if bundleID.components(separatedBy: ".").count < 3 { return false }

        return true
    }

    private func extractIcon(appURL: URL) -> Data? {
        let nsImage = NSWorkspace.shared.icon(forFile: appURL.path)
        nsImage.size = NSSize(width: iconSize, height: iconSize)
        guard let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [.compressionFactor: 0.85])
    }

    func launch(bundleID: String) {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: config)
    }

    func runningApps(includeIcons: Bool = true) -> [RunningApp] {
        let apps = filteredRunningApps()
        let result: [RunningApp] = apps.map { app, bundleID in
            let iconData = includeIcons ? app.bundleURL.flatMap { extractIcon(appURL: $0) } : nil
            return RunningApp(
                id: UUID(),
                bundleID: bundleID,
                name: app.localizedName ?? "Unknown",
                iconPNG: iconData,
                isActive: app.isActive
            )
        }
        return result.sorted {
            if $0.isActive != $1.isActive { return $0.isActive }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func runningAppIconChunks(chunkSize: Int = 1) -> [[MacAppIcon]] {
        let apps = filteredRunningApps()
        let chunks = stride(from: 0, to: apps.count, by: chunkSize).map {
            Array(apps[$0..<min($0 + chunkSize, apps.count)])
        }
        return chunks.map { chunk in
            chunk.compactMap { app, bundleID -> MacAppIcon? in
                guard let url = app.bundleURL, let pngData = self.extractIcon(appURL: url) else { return nil }
                return MacAppIcon(bundleID: bundleID, pngData: pngData)
            }
        }
    }

    private func filteredRunningApps() -> [(app: NSRunningApplication, bundleID: String)] {
        var seen = Set<String>()
        var result: [(NSRunningApplication, String)] = []
        for app in NSWorkspace.shared.runningApplications {
            guard let bundleID = app.bundleIdentifier else { continue }
            guard !seen.contains(bundleID) else { continue }
            guard app.activationPolicy == .regular else { continue }
            guard isRelevantRunningApp(bundleID: bundleID, name: app.localizedName ?? "") else { continue }
            seen.insert(bundleID)
            result.append((app, bundleID))
        }
        return result
    }

    private func isRelevantRunningApp(bundleID: String, name: String) -> Bool {
        for prefix in blockedBundleIDPrefixes {
            if bundleID.lowercased().hasPrefix(prefix.lowercased()) { return false }
        }
        for pattern in blockedNamePatterns {
            if name.contains(pattern) { return false }
        }
        if name.hasSuffix(" Helper") || name.hasSuffix(" Agent") { return false }
        return true
    }

    func quitApp(bundleID: String, force: Bool) -> Bool {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) else { return false }
        if force {
            return app.forceTerminate()
        } else {
            return app.terminate()
        }
    }

    func getRecentProjects(bundleID: String) -> [RecentProject] {
        let plistPath = NSHomeDirectory() + "/Library/Preferences/\(bundleID).plist"
        guard let plist = NSDictionary(contentsOfFile: plistPath) as? [String: Any],
              let records = plist["NSRecentDocumentRecords"] as? [[String: Any]] else { return [] }
        return records.compactMap { record in
            if let data = record["Bookmark"] as? Data ?? record["URL"] as? Data {
                var stale = false
                if let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) {
                    return RecentProject(id: UUID(), name: url.lastPathComponent, path: url.path)
                }
            }
            if let data = record["Name"] as? Data,
               let path = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) {
                return RecentProject(id: UUID(), name: (path as NSString).lastPathComponent, path: path)
            }
            return nil
        }
    }

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .requestAppList:
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                let apps = self.installedApps()
                reply(.appList(apps: apps))

                let pathMap = Dictionary(uniqueKeysWithValues: apps.map { ($0.bundleID, $0.path) })
                let bundleIDs = apps.map { $0.bundleID }
                let chunks = stride(from: 0, to: bundleIDs.count, by: self.chunkSize).map {
                    Array(bundleIDs[$0..<min($0 + self.chunkSize, bundleIDs.count)])
                }

                for chunk in chunks {
                    var iconChunk: [MacAppIcon] = []
                    for bundleID in chunk {
                        guard let path = pathMap[bundleID],
                              let pngData = self.extractIcon(appURL: URL(fileURLWithPath: path))
                        else { continue }
                        iconChunk.append(MacAppIcon(bundleID: bundleID, pngData: pngData))
                    }
                    if !iconChunk.isEmpty { reply(.appIconChunk(icons: iconChunk)) }
                }
            }

        case .launchApp(let bundleID):
            launch(bundleID: bundleID)
            reply(.operationSuccess)

        default:
            break
        }
    }
}
