//
//  DashboardViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//


import Combine
import SwiftUI

final class DashboardViewModel: ObservableObject {
    @Published var isMuted = false
    @Published var isMacLocked = false
    @Published var pairingCodeInput = ""
    @Published private(set) var toast: ToastPresentation? = nil

    private let connectionService: RemoteConnectionServicing
    private var cancellables = Set<AnyCancellable>()
    private var toastDismissTask: Task<Void, Never>?

    init(connectionService: RemoteConnectionServicing = LiveRemoteConnectionService.shared) {
        self.connectionService = connectionService
        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handle($0) }
            .store(in: &cancellables)
    }

    func start() {
        connectionService.startAutoConnect()
        BackTapCoordinator.shared.startIfNeeded()
    }

    func handleForeground() {
        connectionService.handleAppForeground()
        BackTapCoordinator.shared.startIfNeeded()
    }

    func toggleMute() {
        connectionService.send(isMuted ? .unmuteAudio : .muteAudio)
    }

    func lockMac() {
        connectionService.send(.systemLockScreen)
    }

    func shutDownMac() {
        connectionService.send(.systemShutDown)
    }

    func resetPairingCodeIfNeeded(forState isConnected: Bool) {
        guard isConnected else { return }
        pairingCodeInput = ""
    }

    func submitPairingCode() {
        guard pairingCodeInput.count == 6 else { return }
        connectionService.redeem(code: pairingCodeInput)
    }

    func fireToast(_ toast: ToastPresentation) {
        self.toast = toast
        toastDismissTask?.cancel()
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            guard let self, !Task.isCancelled else { return }
            await MainActor.run { withAnimation(.easeOut(duration: 0.28)) { self.toast = nil } }
        }
    }

    private func handle(_ message: FlowMessage) {
        switch message {
        case .muteStateChanged(let muted):
            withAnimation(.easeInOut(duration: 0.20)) { isMuted = muted }
        case .macLockedState(let locked):
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { isMacLocked = locked }
        default:
            break
        }
    }
}
