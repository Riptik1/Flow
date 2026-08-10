//
//  RecentFilesViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import Foundation

final class RecentFilesViewModel: ObservableObject {
    @Published var runningApps: [RunningApp] = []
    @Published var isRefreshing = false
    @Published var isConnected = false
    @Published var mirroringTarget: RunningApp? = nil

    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()
    private var lastRefreshDate: Date? = nil
    private let minRefreshInterval: TimeInterval = 45

    init(connectionService: FlowConnectionServicing = FlowConnectionRepository.shared) {
        self.connectionService = connectionService

        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handleMessage($0) }
            .store(in: &cancellables)

        connectionService.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isConnected = $0 }
            .store(in: &cancellables)
    }

    func onAppear() {
        let shouldFetch: Bool
        if let last = lastRefreshDate {
            shouldFetch = Date().timeIntervalSince(last) > minRefreshInterval
        } else {
            shouldFetch = true
        }
        if shouldFetch { refresh(force: false) }
    }

    func refresh(force: Bool) {
        guard connectionService.isConnected else { return }
        if !force, let last = lastRefreshDate,
           Date().timeIntervalSince(last) < minRefreshInterval { return }
        isRefreshing = true
        lastRefreshDate = Date()
        connectionService.send(.requestRunningApps)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.isRefreshing = false }
    }

    func startMirroring(_ app: RunningApp) {
        mirroringTarget = app
    }

    func activateApp(_ app: RunningApp) { connectionService.send(.activateApp(bundleID: app.bundleID)) }
    func quitApp(_ app: RunningApp, force: Bool) { connectionService.send(.quitApp(bundleID: app.bundleID, force: force)) }

    private func handleMessage(_ message: FlowMessage) {
        switch message {
        case .runningApps(let apps):
            runningApps = apps
            isRefreshing = false
        case .appIconChunk(let icons):
            guard !icons.isEmpty else { break }
            var iconMap: [String: Data] = [:]
            for icon in icons { iconMap[icon.bundleID] = icon.pngData }
            runningApps = runningApps.map { app in
                guard let data = iconMap[app.bundleID] else { return app }
                return RunningApp(id: app.id, bundleID: app.bundleID, name: app.name, iconPNG: data, isActive: app.isActive)
            }
        case .appQuitSuccess:
            connectionService.send(.requestRunningApps)
        case .operationFailure:
            isRefreshing = false
        default:
            break
        }
    }
}
