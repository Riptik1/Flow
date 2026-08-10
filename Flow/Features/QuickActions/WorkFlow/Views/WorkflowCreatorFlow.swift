//
//  WorkflowCreatorFlow.swift
//  Flow
//
//  Created by Riptik Jhajhria on 30/05/26.
//

import SwiftUI

struct WorkflowCreatorFlow: View {
    var existingWorkflow: AppWorkflow?
    let factory: FlowViewModelFactory
    var onSave: (AppWorkflow) -> Void
    var onCancel: () -> Void

    @State private var selectedBundleIDs: Set<String> = []
    @State private var showNaming = false

    init(existingWorkflow: AppWorkflow?, factory: FlowViewModelFactory = ViewModelFactory.shared,
         onSave: @escaping (AppWorkflow) -> Void, onCancel: @escaping () -> Void) {
        self.existingWorkflow = existingWorkflow
        self.factory = factory
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            LaunchAppView(
                mode: .workflowPicker(
                    preselected: existingWorkflow.map { Set($0.appBundleIDs) } ?? [],
                    onDone: { selected in
                        selectedBundleIDs = selected
                        showNaming = true
                    }
                ),
                factory: factory
            )
            .navigationDestination(isPresented: $showNaming) {
                WorkflowNamingView(
                    existingWorkflow: existingWorkflow,
                    selectedBundleIDs: Array(selectedBundleIDs),
                    factory: factory,
                    onSave: onSave,
                    onBack: { showNaming = false }
                )
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .onAppear {
            if let existing = existingWorkflow {
                selectedBundleIDs = Set(existing.appBundleIDs)
            }
        }
    }
}
