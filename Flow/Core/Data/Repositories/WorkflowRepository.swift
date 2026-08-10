//
//  WorkflowRepository.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import Combine
import Foundation

protocol WorkflowRepositoryProtocol: AnyObject {
    var currentWorkflows: [AppWorkflow] { get }
    var workflowsPublisher: AnyPublisher<[AppWorkflow], Never> { get }

    func add(_ workflow: AppWorkflow)
    func update(_ workflow: AppWorkflow)
    func delete(_ workflow: AppWorkflow)
    func usedBackTapKinds(excluding id: UUID?) -> Set<BackTapKind>
}

final class WorkflowRepository: WorkflowRepositoryProtocol, ObservableObject {
    static let shared = WorkflowRepository()

    @Published private(set) var workflows: [AppWorkflow] = []

    var currentWorkflows: [AppWorkflow] { workflows }
    var workflowsPublisher: AnyPublisher<[AppWorkflow], Never> { $workflows.eraseToAnyPublisher() }

    private let store: UserDefaultsCodableStore<[AppWorkflow]>

    init(defaults: UserDefaults = UserDefaults(suiteName: "group.com.flow.app") ?? .standard) {
        store = UserDefaultsCodableStore(key: "com.flow.workflows.v2", defaults: defaults)
        workflows = store.load() ?? []
    }

    func add(_ workflow: AppWorkflow) {
        workflows.append(workflow)
        store.save(workflows)
    }

    func update(_ workflow: AppWorkflow) {
        guard let idx = workflows.firstIndex(where: { $0.id == workflow.id }) else { return }
        workflows[idx] = workflow
        store.save(workflows)
    }

    func delete(_ workflow: AppWorkflow) {
        workflows.removeAll { $0.id == workflow.id }
        store.save(workflows)
    }

    func usedBackTapKinds(excluding id: UUID? = nil) -> Set<BackTapKind> {
        Set(workflows.filter { $0.backTapEnabled && $0.id != id }.map { $0.backTapKind })
    }
}
