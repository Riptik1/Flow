//
//  ClipboardViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import SwiftUI
import UIKit

final class ClipboardViewModel: ObservableObject {
    @Published private(set) var items: [ClipboardItem] = []
    @Published private(set) var isRefreshing = false

    struct ItemPair: Identifiable {
        let id: Int
        let left: ClipboardItem
        let right: ClipboardItem?
    }

    private let repository: ClipboardRepositoryProtocol
    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()

    init(repository: ClipboardRepositoryProtocol = ClipboardRepository.shared,
         connectionService: FlowConnectionServicing = LiveFlowConnectionService.shared) {
        self.repository = repository
        self.connectionService = connectionService
        items = repository.currentItems

        repository.itemsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newItems in
                withAnimation(.easeInOut(duration: 0.18)) { self?.items = newItems }
            }
            .store(in: &cancellables)

        repository.isRefreshingPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isRefreshing = $0 }
            .store(in: &cancellables)

        connectionService.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                if connected { self?.refresh() }
            }
            .store(in: &cancellables)
    }

    func onAppear() {
        refresh()
    }

    func refresh() {
        repository.refresh()
    }

    func copyToiPhone(_ item: ClipboardItem) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        if let text = item.text {
            UIPasteboard.general.string = text
        } else if let data = item.imageData, let img = UIImage(data: data) {
            UIPasteboard.general.image = img
        }
    }

    func pasteToMac(_ item: ClipboardItem) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        connectionService.send(.pasteClipboardItem(id: item.id))
    }

    func deleteItem(_ item: ClipboardItem) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        repository.delete(item)
    }
}
