//
//  BackTapShortcutView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 30/05/26.
//

import SwiftUI

struct BackTapShortcutView: View {
    let onSave: (AppWorkflow) -> Void

    @StateObject private var vm: BackTapShortcutViewModel
    @Environment(\.dismiss) private var dismiss

    init(workflow: AppWorkflow, onSave: @escaping (AppWorkflow) -> Void) {
        self.onSave = onSave
        _vm = StateObject(wrappedValue: BackTapShortcutViewModel(workflow: workflow))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        BackTapInfoCard(workflow: vm.workflow, accent: vm.accent)
                        BackTapSystemConflictCard()
                        BackTapToggleCard(vm: vm)
                        if vm.isEnabled {
                            BackTapPickerSection(vm: vm)
                                .transition(.move(edge: .top).combined(with: .opacity))
                            BackTapTestSection(vm: vm)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 60)
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: vm.isEnabled)

                if vm.showToast, let msg = vm.toastMessage {
                    BackTapToastView(message: msg, success: vm.toastSuccess)
                }
            }
            .navigationTitle(vm.workflow.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(vm.buildSavedWorkflow())
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(vm.accent)
                }
            }
        }
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
    }
}
