//
//  BackTapCoordinator.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import UIKit

final class BackTapCoordinator: ObservableObject {
    static let shared = BackTapCoordinator(
        repository: WorkflowRepository.shared,
        connectionService: LiveFlowConnectionService.shared
    )

    @Published var lastTriggeredWorkflow: AppWorkflow? = nil
    @Published var rawTapFired: Bool = false

    private let engine: BackTapEngine
    private let repository: WorkflowRepositoryProtocol
    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()

    init(repository: WorkflowRepositoryProtocol,
         connectionService: FlowConnectionServicing,
         engine: BackTapEngine = .shared) {
        self.repository = repository
        self.connectionService = connectionService
        self.engine = engine

        repository.workflowsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.rebind() }
            .store(in: &cancellables)
    }

    func startIfNeeded() {
        let hasAny = repository.currentWorkflows.contains { $0.backTapEnabled }
        guard hasAny, engine.isAvailable else { return }
        engine.startGlobal()
        rebind()
    }

    func stop() {
        engine.stopGlobal()
        engine.onGesture = nil
        engine.onRawTap  = nil
    }

    func rebind() {
        let enabled = repository.currentWorkflows.filter { $0.backTapEnabled }

        guard !enabled.isEmpty, engine.isAvailable else {
            engine.onGesture = nil
            engine.onRawTap  = nil
            return
        }

        engine.startGlobal()

        engine.onRawTap = { [weak self] in
            guard let self else { return }
            self.rawTapFired = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.rawTapFired = false
            }
        }

        engine.onGesture = { [weak self] kind in
            guard let self else { return }
            guard let wf = enabled.first(where: { $0.backTapKind == kind }) else { return }
            self.launchWorkflow(wf)
        }
    }

    private func launchWorkflow(_ wf: AppWorkflow) {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        lastTriggeredWorkflow = wf
        for bundleID in wf.appBundleIDs {
            connectionService.send(.launchApp(bundleID: bundleID))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.lastTriggeredWorkflow = nil
        }
    }
}
