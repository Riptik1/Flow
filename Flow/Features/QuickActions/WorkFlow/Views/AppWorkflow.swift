//
//  AppWorkflow.swift
//  Flow
//
//  Created by Riptik Jhajhria on 30/05/26.
//

import SwiftUI
import Combine

final class WorkflowStore: ObservableObject {
    static let shared = WorkflowStore()

    @Published var workflows: [AppWorkflow] = [] {
        didSet { save() }
    }

    private let defaults = UserDefaults(suiteName: "group.com.flow.app") ?? .standard
    private let key = "com.flow.workflows.v2"

    private init() { load() }

    func add(_ workflow: AppWorkflow) { workflows.append(workflow) }

    func update(_ workflow: AppWorkflow) {
        if let idx = workflows.firstIndex(where: { $0.id == workflow.id }) {
            workflows[idx] = workflow
        }
    }

    func delete(_ workflow: AppWorkflow) { workflows.removeAll { $0.id == workflow.id } }

    func usedBackTapKinds(excluding id: UUID? = nil) -> Set<BackTapKind> {
        Set(workflows.filter { $0.backTapEnabled && $0.id != id }.map { $0.backTapKind })
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(workflows) else { return }
        defaults.set(data, forKey: key)
        defaults.synchronize()
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([AppWorkflow].self, from: data)
        else { return }
        workflows = decoded
    }
}
