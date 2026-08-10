//
//  ClipboardRepository.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import Foundation

protocol ClipboardRepositoryProtocol: AnyObject {
    var currentItems: [ClipboardItem] { get }
    var itemsPublisher: AnyPublisher<[ClipboardItem], Never> { get }
    var isRefreshingPublisher: AnyPublisher<Bool, Never> { get }

    func refresh()
    func delete(_ item: ClipboardItem)
}

final class ClipboardRepository: ClipboardRepositoryProtocol, ObservableObject {
    static let shared = ClipboardRepository(connectionService: LiveFlowConnectionService.shared)

    private static let maxItems = 50

    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var isRefreshing = false

    var currentItems: [ClipboardItem] { items }
    var itemsPublisher: AnyPublisher<[ClipboardItem], Never> { $items.eraseToAnyPublisher() }
    var isRefreshingPublisher: AnyPublisher<Bool, Never> { $isRefreshing.eraseToAnyPublisher() }

    private let cacheStore       = UserDefaultsCodableStore<[ClipboardItem]>(key: "flow_clipboard_cache")
    private let deletedIDsStore  = UserDefaultsStringSetStore(key: "flow_clipboard_deleted_ids", maxCount: 500)
    private let deletedTextStore = UserDefaultsStringSetStore(key: "flow_clipboard_deleted_texts", maxCount: 300)

    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimeoutTask: DispatchWorkItem?

    init(connectionService: FlowConnectionServicing) {
        self.connectionService = connectionService
        loadCached()
        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handle($0) }
            .store(in: &cancellables)
    }

    func refresh() {
        guard connectionService.isConnected else { return }
        isRefreshing = true
        connectionService.send(.requestClipboardHistory)
        let task = DispatchWorkItem { [weak self] in self?.isRefreshing = false }
        refreshTimeoutTask?.cancel()
        refreshTimeoutTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: task)
    }

    func delete(_ item: ClipboardItem) {
        var ids = deletedIDsStore.load()
        ids.insert(item.id.uuidString)
        deletedIDsStore.save(ids)
        if let text = item.text {
            var texts = deletedTextStore.load()
            texts.insert(text)
            deletedTextStore.save(texts)
        }
        items.removeAll { $0.id == item.id }
        cacheStore.save(Array(items.prefix(Self.maxItems)))
    }

    private func loadCached() {
        guard let cached = cacheStore.load() else { return }
        items = filteringDeleted(cached)
    }

    private func filteringDeleted(_ list: [ClipboardItem]) -> [ClipboardItem] {
        let ids = deletedIDsStore.load()
        let texts = deletedTextStore.load()
        return list.filter { item in
            !ids.contains(item.id.uuidString) &&
            !(item.text.map { texts.contains($0) } ?? false)
        }
    }

    private func handle(_ message: FlowMessage) {
        switch message {
        case .clipboardHistory(let history):
            isRefreshing = false
            refreshTimeoutTask?.cancel()
            items = Array(filteringDeleted(history).prefix(Self.maxItems))
            cacheStore.save(items)

        case .clipboardDidChange(let item):
            isRefreshing = false
            let ids = deletedIDsStore.load()
            let texts = deletedTextStore.load()
            guard !ids.contains(item.id.uuidString) else { return }
            if let text = item.text, texts.contains(text) { return }
            if let text = item.text { items.removeAll { $0.text == text } }
            else { items.removeAll { $0.imageData != nil && $0.text == nil } }
            items.insert(item, at: 0)
            if items.count > Self.maxItems { items = Array(items.prefix(Self.maxItems)) }
            cacheStore.save(items)

        default:
            break
        }
    }
}
