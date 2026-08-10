//
//  LaunchAppViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import Foundation

final class LaunchAppViewModel: ObservableObject {
    @Published var apps: [MacApp] = []
    @Published var filteredApps: [MacApp] = []
    @Published var searchText: String = "" { didSet { applyFilter() } }
    @Published var showSearch: Bool = false { didSet { if !showSearch { searchText = "" } } }
    @Published var isLoading: Bool = false
    @Published var error: String? = nil

    private let repository: AppRepositoryProtocol
    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()

    init(repository: AppRepositoryProtocol = AppRepository.shared,
         connectionService: FlowConnectionServicing = LiveFlowConnectionService.shared) {
        self.repository = repository
        self.connectionService = connectionService

        if !repository.currentApps.isEmpty {
            apps = repository.currentApps
            applyFilter()
        }

        repository.appsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updated in
                guard let self, !updated.isEmpty else { return }
                self.apps = updated
                self.isLoading = false
                self.applyFilter()
            }
            .store(in: &cancellables)

        repository.isFetchingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fetching in
                guard let self else { return }
                if fetching && self.apps.isEmpty { self.isLoading = true }
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        if !repository.currentApps.isEmpty {
            apps = repository.currentApps
            applyFilter()
        }
        guard connectionService.isConnected else {
            if apps.isEmpty { error = "Not connected to a Mac. Please connect first." }
            return
        }
        error = nil
        isLoading = apps.isEmpty
        repository.prefetchIfNeeded()
    }

    func fetchApps() {
        guard connectionService.isConnected else {
            error = "Not connected to a Mac. Please connect first."
            return
        }
        isLoading = apps.isEmpty
        error = nil
        repository.prefetchIfNeeded()
    }

    func forceRefresh() {
        apps = []
        filteredApps = []
        isLoading = true
        error = nil
        repository.forceRefresh()
    }

    func launch(_ app: MacApp) {
        connectionService.send(.launchApp(bundleID: app.bundleID))
    }

    private func applyFilter() {
        let q = searchText.trimmingCharacters(in: .whitespaces)
        filteredApps = q.isEmpty ? apps : apps.filter { $0.name.localizedCaseInsensitiveContains(q) }
    }
}
