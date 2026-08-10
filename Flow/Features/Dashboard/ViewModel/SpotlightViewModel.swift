//
//  SpotlightViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//


import Combine
import Foundation

final class SpotlightViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [SpotlightResult] = []
    @Published var isSearching: Bool = false

    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()
    private var debounceTask: Task<Void, Never>?

    init(connectionService: FlowConnectionServicing = FlowConnectionRepository.shared) {
        self.connectionService = connectionService
        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                if case .spotlightResults(let r) = message {
                    self?.results = r
                    self?.isSearching = false
                }
            }
            .store(in: &cancellables)
    }

    func scheduleSearch() {
        debounceTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { results = []; isSearching = false; return }
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard let self, !Task.isCancelled else { return }
            self.search()
        }
    }

    func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, connectionService.isConnected else { return }
        isSearching = true
        connectionService.send(.spotlightSearch(query: q))
    }

    func openResult(_ result: SpotlightResult) {
        connectionService.send(.spotlightOpen(path: result.path))
    }

    func reset() {
        query = ""
        results = []
        isSearching = false
        debounceTask?.cancel()
    }
}
