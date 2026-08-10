//
//  WorkflowsViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import UIKit
import SwiftUI

final class WorkflowsViewModel: ObservableObject {
    @Published private(set) var workflows: [AppWorkflow] = []

    private let repository: WorkflowRepositoryProtocol
    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()

    init(repository: WorkflowRepositoryProtocol = WorkflowRepository.shared,
         connectionService: FlowConnectionServicing = LiveFlowConnectionService.shared) {
        self.repository = repository
        self.connectionService = connectionService
        workflows = repository.currentWorkflows
        repository.workflowsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.workflows = $0 }
            .store(in: &cancellables)
    }

    func add(_ workflow: AppWorkflow) { repository.add(workflow) }
    func update(_ workflow: AppWorkflow) { repository.update(workflow) }
    func delete(_ workflow: AppWorkflow) { repository.delete(workflow) }

    func launch(_ workflow: AppWorkflow) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        for bundleID in workflow.appBundleIDs {
            connectionService.send(.launchApp(bundleID: bundleID))
        }
    }
}

final class WorkflowNamingViewModel: ObservableObject {
    @Published var workflowName: String
    @Published var selectedIcon: String
    @Published var selectedColorHex: String

    let existingWorkflow: AppWorkflow?
    let selectedBundleIDs: [String]

    init(existingWorkflow: AppWorkflow?, selectedBundleIDs: [String]) {
        self.existingWorkflow = existingWorkflow
        self.selectedBundleIDs = selectedBundleIDs
        _workflowName     = Published(initialValue: existingWorkflow?.name ?? "")
        _selectedIcon     = Published(initialValue: existingWorkflow?.iconName ?? "briefcase.fill")
        _selectedColorHex = Published(initialValue: existingWorkflow?.iconColorHex ?? "7D32F5")
    }

    var accentColor: Color { Color(hex: selectedColorHex) }
    var canSave: Bool { !workflowName.trimmingCharacters(in: .whitespaces).isEmpty }

    func buildWorkflow() -> AppWorkflow {
        AppWorkflow(
            id: existingWorkflow?.id ?? UUID(),
            name: workflowName.trimmingCharacters(in: .whitespaces),
            iconName: selectedIcon,
            iconColorHex: selectedColorHex,
            appBundleIDs: selectedBundleIDs,
            backTapEnabled: existingWorkflow?.backTapEnabled ?? false,
            backTapKind: existingWorkflow?.backTapKind ?? .doubleTap
        )
    }
}
