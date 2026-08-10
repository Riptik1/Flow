//
//  AppIconLoaderViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import UIKit

final class AppIconLoaderViewModel: ObservableObject {
    @Published var image: UIImage? = nil

    private var bundleID: String = ""
    private var cancellable: AnyCancellable?
    private let repository: AppRepositoryProtocol

    init(repository: AppRepositoryProtocol = AppRepository.shared) {
        self.repository = repository
    }

    func load(bundleID: String) {
        guard bundleID != self.bundleID else { return }
        self.bundleID = bundleID
        if let existing = repository.icon(for: bundleID) {
            image = existing
            return
        }
        cancellable = repository.iconUpdated
            .filter { $0 == bundleID }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] id in
                self?.image = self?.repository.icon(for: id)
            }
    }
}
