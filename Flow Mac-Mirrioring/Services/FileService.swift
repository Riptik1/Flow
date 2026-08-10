//
//  FileService.swift
//  Flow
//
//  Created by Riptik Jhajhria on 24/05/26.
//

import Foundation
import AppKit

final class FileService {
    static let shared = FileService()
    private init() { _ = ClipboardService.shared }

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .checkPermissions: checkPermissions(reply: reply)
        case .listDirectory(let path): listDirectory(path, reply: reply)
        case .getRecents: getRecents(limit: 60, reply: reply)
        case .requestRecentFiles(let limit): getRecents(limit: limit, reply: reply)
        case .previewFile(let path): previewFile(path, reply: reply)
        case .shareFile(let path): transferFile(path, reply: reply)
        case .saveFileToDevice(let path): saveFileToDevice(path, reply: reply)
        case .moveItem(let f, let t): moveItem(from: f, to: t, reply: reply)
        case .copyItem(let f, let t): copyItem(from: f, to: t, reply: reply)
        case .deleteItem(let path): deleteItem(path: path, reply: reply)
        case .requestRunningApps:
            DispatchQueue.global(qos: .userInitiated).async {
                reply(.runningApps(apps: AppLaunchService.shared.runningApps(includeIcons: false)))
                for chunk in AppLaunchService.shared.runningAppIconChunks() where !chunk.isEmpty {
                    reply(.appIconChunk(icons: chunk))
                }
            }
        case .quitApp(let bundleID, let force):
            DispatchQueue.global(qos: .userInitiated).async {
                let ok = AppLaunchService.shared.quitApp(bundleID: bundleID, force: force)
                reply(ok ? .appQuitSuccess : .appQuitFailure(error: "Failed to quit"))
            }
        case .requestAppRecentProjects(let bundleID):
            DispatchQueue.global(qos: .userInitiated).async {
                let p = AppLaunchService.shared.getRecentProjects(bundleID: bundleID)
                reply(.appRecentProjects(bundleID: bundleID, projects: p))
            }
        case .openProject(let path):
            DispatchQueue.global(qos: .userInitiated).async {
                NSWorkspace.shared.open(URL(fileURLWithPath: path)); reply(.operationSuccess)
            }
        case .activateApp(let bundleID):
            DispatchQueue.main.async {
                if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }) {
                    if #available(macOS 14.0, *) { app.activate(options: [.activateAllWindows]) }
                    else { app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows]) }
                    reply(.operationSuccess)
                } else { reply(.operationFailure(error: "App not running")) }
            }
        case .keyPress: KeyboardService.shared.handle(message)
        case .touchBarStateRequest, .touchBarAction, .typeText: TouchBarService.shared.handle(message, reply: reply)
        case .spotlightOpen(let path): NSWorkspace.shared.open(URL(fileURLWithPath: path))
        default: TrackpadService.shared.handle(message)
        }
    }

    private func previewFile(_ path: String, reply: @escaping (FlowMessage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let resolved = self.resolvePath(path)
            let url = URL(fileURLWithPath: resolved)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir) else {
                reply(.operationFailure(error: "File not found: \(url.lastPathComponent)")); return
            }
            if isDir.boolValue {
                DispatchQueue.main.async { NSWorkspace.shared.open(url) }
                reply(.operationFailure(error: "Folder opened on Mac")); return
            }
            let attrs = try? FileManager.default.attributesOfItem(atPath: resolved)
            let size = (attrs?[.size] as? Int64) ?? 0
            let limit: Int64 = 150 * 1024 * 1024
            if size > limit {
                let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                reply(.operationFailure(error: "FILE_TOO_LARGE_PREVIEW:\(url.lastPathComponent):\(sizeStr):\(path)"))
                return
            }
            do {
                let data = try Data(contentsOf: url)
                let uti = (try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier) ?? "public.data"
                reply(.filePreview(data: data, uti: uti))
            } catch {
                reply(.operationFailure(error: "Could not read file: \(error.localizedDescription)"))
            }
        }
    }

    private func transferFile(_ path: String, reply: @escaping (FlowMessage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let resolved = self.resolvePath(path)
            let url = URL(fileURLWithPath: resolved)
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: resolved, isDirectory: &isDir) else {
                reply(.operationFailure(error: "File not found: \(url.lastPathComponent)")); return
            }
            if isDir.boolValue {
                reply(.operationFailure(error: "Folders cannot be shared.\n\nUse \"Save to Files\" instead.")); return
            }
            let attrs = try? FileManager.default.attributesOfItem(atPath: resolved)
            let size = (attrs?[.size] as? Int64) ?? 0
            let limit: Int64 = 150 * 1024 * 1024
            if size > limit {
                let sizeStr = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                reply(.operationFailure(error: "\(url.lastPathComponent) is \(sizeStr) — too large to share (max 150 MB).\n\nUse \"Save to Files\" instead.")); return
            }
            do {
                let data = try Data(contentsOf: url)
                let uti = (try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier) ?? "public.data"
                reply(.shareData(data: data, uti: uti))
            } catch {
                reply(.operationFailure(error: error.localizedDescription))
            }
        }
    }

    private func saveFileToDevice(_ path: String, reply: @escaping (FlowMessage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let resolved = self.resolvePath(path)
            let url = URL(fileURLWithPath: resolved)
            let fm = FileManager.default
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: resolved, isDirectory: &isDir) else {
                reply(.operationFailure(error: "File not found: \(url.lastPathComponent)")); return
            }
            if isDir.boolValue {
                self.zipFolderAndSend(url: url, fm: fm, reply: reply)
                return
            }
            let attrs = try? fm.attributesOfItem(atPath: resolved)
            let size = (attrs?[.size] as? Int64) ?? 0
            let limit: Int64 = 2 * 1024 * 1024 * 1024
            if size > limit {
                let s = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
                reply(.operationFailure(error: "\(url.lastPathComponent) is \(s).\n\nFiles over 2 GB cannot be transferred wirelessly. Use AirDrop or a cable.")); return
            }
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                let uti = (try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier) ?? "public.data"
                reply(.saveFileData(data: data, uti: uti))
            } catch {
                reply(.operationFailure(error: "Could not read: \(error.localizedDescription)"))
            }
        }
    }

    private func zipFolderAndSend(url: URL, fm: FileManager, reply: @escaping (FlowMessage) -> Void) {
        let tmp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let zip = tmp.appendingPathComponent(url.lastPathComponent + ".zip")
        do {
            try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
            task.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", url.path, zip.path]
            let pipe = Pipe()
            task.standardError = pipe
            try task.run()
            task.waitUntilExit()
            guard task.terminationStatus == 0 else {
                let errMsg = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                try? fm.removeItem(at: tmp)
                reply(.operationFailure(error: "Could not zip folder.\n\(errMsg.trimmingCharacters(in: .whitespacesAndNewlines))")); return
            }
            let zipAttrs = try? fm.attributesOfItem(atPath: zip.path)
            let zipSize = (zipAttrs?[.size] as? Int64) ?? 0
            let limit: Int64 = 2 * 1024 * 1024 * 1024
            if zipSize > limit {
                let s = ByteCountFormatter.string(fromByteCount: zipSize, countStyle: .file)
                try? fm.removeItem(at: tmp)
                reply(.operationFailure(error: "Zipped folder is \(s) — too large to transfer wirelessly.")); return
            }
            let data = try Data(contentsOf: zip, options: .mappedIfSafe)
            try? fm.removeItem(at: tmp)
            reply(.saveFileData(data: data, uti: "public.zip-archive"))
        } catch {
            try? fm.removeItem(at: tmp)
            reply(.operationFailure(error: "Could not zip folder: \(error.localizedDescription)"))
        }
    }

    private func checkPermissions(reply: @escaping (FlowMessage) -> Void) {
        let ok = FileManager.default.isReadableFile(atPath: NSHomeDirectory() + "/Library/Safari/Bookmarks.plist")
        reply(.permissionStatus(granted: ok, missing: ok ? [] : ["Full Disk Access"]))
    }

    private func listDirectory(_ path: String, reply: @escaping (FlowMessage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let resolved = self.resolvePath(path)
            let url = URL(fileURLWithPath: resolved)
            let fm = FileManager.default
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: resolved, isDirectory: &isDir) else {
                reply(.operationFailure(error: "Folder not found: \(url.lastPathComponent)")); return
            }
            guard isDir.boolValue else {
                reply(.operationFailure(error: "\(url.lastPathComponent) is not a folder.")); return
            }
            let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .typeIdentifierKey, .isDirectoryKey]
            do {
                let contents = try fm.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)
                let files: [RemoteFileItem] = contents.map { itemURL in
                    let v = try? itemURL.resourceValues(forKeys: Set(keys))
                    let d = v?.isDirectory ?? false
                    return RemoteFileItem(id: UUID(), name: itemURL.lastPathComponent, path: itemURL.path,
                        dateModified: v?.contentModificationDate?.timeIntervalSince1970 ?? 0,
                        size: d ? nil : v?.fileSize.map { Int64($0) } ?? nil,
                        isDirectory: d, uti: v?.typeIdentifier ?? "public.data")
                }.sorted {
                    if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }
                reply(.directoryContents(files: files))
            } catch {
                let c = (error as NSError).code
                if c == NSFileReadNoPermissionError || c == 257 {
                    reply(.operationFailure(error: "Access denied.\n\nEnable Full Disk Access in:\nSystem Settings → Privacy & Security → Full Disk Access"))
                } else { reply(.operationFailure(error: error.localizedDescription)) }
            }
        }
    }

    private func getRecents(limit: Int, reply: @escaping (FlowMessage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            let dirs: [URL] = ["Documents","Downloads","Desktop","Developer","Movies","Music","Pictures"]
                .map { home.appendingPathComponent($0) }
                .filter { fm.fileExists(atPath: $0.path) }
            let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey, .typeIdentifierKey, .isDirectoryKey]
            let cutoff = Date(timeIntervalSinceNow: -30 * 24 * 3600)
            var all: [RemoteFileItem] = []
            for dir in dirs {
                guard let contents = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: Array(keys), options: .skipsHiddenFiles) else { continue }
                for u in contents {
                    let v = try? u.resourceValues(forKeys: keys)
                    let d = v?.isDirectory ?? false
                    guard let mod = v?.contentModificationDate, mod > cutoff else { continue }
                    all.append(RemoteFileItem(id: UUID(), name: u.lastPathComponent, path: u.path,
                        dateModified: mod.timeIntervalSince1970,
                        size: d ? nil : v?.fileSize.map { Int64($0) } ?? nil,
                        isDirectory: d, uti: v?.typeIdentifier ?? "public.data"))
                }
            }
            all.sort { $0.dateModified > $1.dateModified }
            reply(.recentFiles(files: Array(all.prefix(limit))))
        }
    }

    private func moveItem(from: String, to: String, reply: @escaping (FlowMessage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do { try FileManager.default.moveItem(atPath: self.resolvePath(from), toPath: self.resolvePath(to)); reply(.operationSuccess) }
            catch { reply(.operationFailure(error: error.localizedDescription)) }
        }
    }

    private func copyItem(from: String, to: String, reply: @escaping (FlowMessage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do { try FileManager.default.copyItem(atPath: self.resolvePath(from), toPath: self.resolvePath(to)); reply(.operationSuccess) }
            catch { reply(.operationFailure(error: error.localizedDescription)) }
        }
    }

    private func deleteItem(path: String, reply: @escaping (FlowMessage) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do { try FileManager.default.removeItem(atPath: self.resolvePath(path)); reply(.operationSuccess) }
            catch { reply(.operationFailure(error: error.localizedDescription)) }
        }
    }

    func resolvePath(_ path: String) -> String {
        guard path.hasPrefix("~") else { return path }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return path == "~" ? home : home + path.dropFirst()
    }
}
