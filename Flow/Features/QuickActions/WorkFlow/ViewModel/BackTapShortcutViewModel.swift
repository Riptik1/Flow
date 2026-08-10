//
//  BackTapShortcutViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI
import Combine

final class BackTapShortcutViewModel: ObservableObject {
    let workflow: AppWorkflow

    @Published var isEnabled: Bool
    @Published var selectedKind: BackTapKind
    @Published var toastMessage: String? = nil
    @Published var toastSuccess: Bool = false
    @Published var showToast: Bool = false
    @Published var ripple: Bool = false
    @Published var testTapCount: Int = 0
    @Published var rawPulse: Bool = false

    var accent: Color { Color(hex: workflow.iconColorHex) }

    private let repository: WorkflowRepositoryProtocol
    private let coordinator: BackTapCoordinator
    private let engine: BackTapEngine
    private var resetCountTimer: Timer?

    init(workflow: AppWorkflow,
         repository: WorkflowRepositoryProtocol = WorkflowRepository.shared,
         coordinator: BackTapCoordinator = .shared,
         engine: BackTapEngine = .shared) {
        self.workflow = workflow
        self.repository = repository
        self.coordinator = coordinator
        self.engine = engine
        _isEnabled = Published(initialValue: workflow.backTapEnabled)
        _selectedKind = Published(initialValue: workflow.backTapKind)
    }

    func isTaken(_ kind: BackTapKind) -> Bool {
        repository.usedBackTapKinds(excluding: workflow.id).contains(kind)
    }

    func onAppear() {
        if isEnabled { attachTestListener() }
    }

    func onDisappear() {
        resetCountTimer?.invalidate()
        coordinator.rebind()
    }

    func setEnabled(_ value: Bool) {
        isEnabled = value
        if value {
            attachTestListener()
            coordinator.startIfNeeded()
        } else {
            testTapCount = 0
            coordinator.rebind()
        }
    }

    func selectKind(_ kind: BackTapKind) {
        guard !isTaken(kind) else { return }
        selectedKind = kind
        testTapCount = 0
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        attachTestListener()
    }

    func buildSavedWorkflow() -> AppWorkflow {
        var w = workflow
        w.backTapEnabled = isEnabled
        w.backTapKind = selectedKind
        return w
    }

    func numStr(_ kind: BackTapKind) -> String {
        switch kind { case .doubleTap: return "2"; case .tripleTap: return "3"; case .quadTap: return "4" }
    }

    func kindCount(_ kind: BackTapKind) -> Int {
        switch kind { case .doubleTap: return 2; case .tripleTap: return 3; case .quadTap: return 4 }
    }

    func kindDesc(_ kind: BackTapKind) -> String {
        switch kind {
        case .doubleTap: return "Two firm taps — may conflict with iOS Back Tap"
        case .tripleTap: return "Three firm taps — best reliability"
        case .quadTap:   return "Four firm taps — most distinctive"
        }
    }

    private func attachTestListener() {
        testTapCount = 0
        engine.startGlobal()

        engine.onRawTap = { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.12, dampingFraction: 0.55)) { self.rawPulse = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { self.rawPulse = false }
            }
        }

        engine.onGesture = { [weak self] detected in
            guard let self else { return }
            let needed = self.kindCount(self.selectedKind)
            let got = self.kindCount(detected)
            withAnimation { self.testTapCount = min(got, needed) }

            self.resetCountTimer?.invalidate()
            self.resetCountTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                withAnimation { self?.testTapCount = 0 }
            }

            if detected == self.selectedKind {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                withAnimation { self.ripple = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) {
                    withAnimation { self.ripple = false }
                }
                self.showToastMsg("✓ \(detected.rawValue) detected — workflow will launch!", success: true)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                self.showToastMsg("Got \(got) taps, need \(needed)", success: false)
            }
        }
    }

    private func showToastMsg(_ msg: String, success: Bool) {
        toastMessage = msg
        toastSuccess = success
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { showToast = true }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            await MainActor.run { withAnimation { self?.showToast = false } }
        }
    }
}
