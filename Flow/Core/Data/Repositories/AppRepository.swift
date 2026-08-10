//
//  AppRepository.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import Foundation
import UIKit

protocol AppRepositoryProtocol: AnyObject {
    var currentApps: [MacApp] { get }
    var appsPublisher: AnyPublisher<[MacApp], Never> { get }
    var isFetchingApps: Bool { get }
    var isFetchingPublisher: AnyPublisher<Bool, Never> { get }
    var hasFetchedApps: Bool { get }
    var iconUpdated: AnyPublisher<String, Never> { get }

    func icon(for bundleID: String) -> UIImage?
    func prefetchIfNeeded()
    func forceRefresh()
}

final class AppRepository: AppRepositoryProtocol, ObservableObject {
    static let shared = AppRepository(connectionService: LiveFlowConnectionService.shared)

    @Published private(set) var apps: [MacApp] = []
    @Published private(set) var isFetchingApps = false
    @Published private(set) var hasFetchedApps = false

    var currentApps: [MacApp] { apps }
    var appsPublisher: AnyPublisher<[MacApp], Never> { $apps.eraseToAnyPublisher() }
    var isFetchingPublisher: AnyPublisher<Bool, Never> { $isFetchingApps.eraseToAnyPublisher() }

    private var icons: [String: UIImage] = [:]
    private let iconsSubject = PassthroughSubject<String, Never>()
    var iconUpdated: AnyPublisher<String, Never> { iconsSubject.eraseToAnyPublisher() }

    private let appListStore = UserDefaultsCodableStore<[MacApp]>(key: "flow.appList.v3")
    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()
    private let bgQueue = DispatchQueue(label: "flow.appRepository.bg", qos: .utility)

    private var iconsDir: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("FlowIcons2", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    init(connectionService: FlowConnectionServicing) {
        self.connectionService = connectionService
        if let cached = appListStore.load(), !cached.isEmpty {
            apps = cached
        }
        loadIconsFromDisk()
        connectionService.messageStream
            .receive(on: bgQueue)
            .sink { [weak self] message in self?.handle(message) }
            .store(in: &cancellables)
    }

    func icon(for bundleID: String) -> UIImage? {
        if let cached = icons[bundleID] { return cached }
        guard let data = try? Data(contentsOf: iconFile(for: bundleID)),
              let img = UIImage(data: data) else { return nil }
        icons[bundleID] = img
        return img
    }

    func prefetchIfNeeded() {
        guard !hasFetchedApps, !isFetchingApps, connectionService.isConnected else { return }
        isFetchingApps = true
        connectionService.send(.requestAppList)
    }

    func forceRefresh() {
        guard connectionService.isConnected else { return }
        hasFetchedApps = false
        isFetchingApps = true
        apps = []
        icons = [:]
        connectionService.send(.requestAppList)
    }

    private func safeFileName(for bundleID: String) -> String {
        bundleID.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? bundleID
    }

    private func iconFile(for bundleID: String) -> URL {
        iconsDir.appendingPathComponent("\(safeFileName(for: bundleID)).png")
    }

    private func loadIconsFromDisk() {
        bgQueue.async { [weak self] in
            guard let self else { return }
            let dir = self.iconsDir
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey],
                options: .skipsHiddenFiles
            ) else { return }

            var loaded: [(String, UIImage)] = []
            for file in files where file.pathExtension == "png" {
                let encoded = file.deletingPathExtension().lastPathComponent
                guard let bundleID = encoded.removingPercentEncoding else { continue }
                guard let data = try? Data(contentsOf: file),
                      let img = UIImage(data: data) else { continue }
                loaded.append((bundleID, img))
            }
            guard !loaded.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for (id, img) in loaded {
                    self.icons[id] = img
                    self.iconsSubject.send(id)
                }
            }
        }
    }

    private func handle(_ message: FlowMessage) {
        switch message {
        case .appList(let received):
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.apps = received
                self.hasFetchedApps = true
                self.isFetchingApps = false
            }
            appListStore.save(received)

        case .appIconChunk(let chunk):
            var decoded: [(String, UIImage, Data)] = []
            for item in chunk {
                guard let img = UIImage(data: item.pngData) else { continue }
                let size = img.size
                guard size.width > 0, size.height > 0 else { continue }
                let renderer = UIGraphicsImageRenderer(size: size)
                let png = renderer.pngData { _ in img.draw(in: CGRect(origin: .zero, size: size)) }
                decoded.append((item.bundleID, img, png))
            }
            for (bundleID, _, png) in decoded {
                try? png.write(to: self.iconFile(for: bundleID), options: .atomic)
            }
            guard !decoded.isEmpty else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                for (id, img, _) in decoded {
                    self.icons[id] = img
                    self.iconsSubject.send(id)
                }
            }

        default:
            break
        }
    }
}
