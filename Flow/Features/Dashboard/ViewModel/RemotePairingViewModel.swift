import Foundation
import Combine
#if canImport(AppKit)

@MainActor
final class RemotePairingViewModel: ObservableObject {
    static let shared = RemotePairingViewModel()

    @Published var pairingCode: String?
    @Published var remainingSeconds: Int = 0
    @Published var isBusy: Bool = false
    @Published var errorMessage: String?

    private let backend = FlowBackendClient.shared
    private var countdownTask: Task<Void, Never>?

    private init() {}

    func generateCode() {
        guard !isBusy else {
            flowLog("[Flow][Pairing] generateCode: already busy, ignoring tap")
            return
        }
        flowLog("[Flow][Pairing] generateCode: start")
        isBusy = true
        errorMessage = nil

        Task {
            do {
                flowLog("[Flow][Pairing] generateCode: ensuring device is registered")
                try await RemoteConnectionManager.shared.ensureRegistered()
                flowLog("[Flow][Pairing] generateCode: registered, requesting code from backend")
                let response = try await backend.generatePairingCode()
                flowLog("[Flow][Pairing] generateCode: got a code expiring at \(response.expiresAt)")
                pairingCode = response.code
                startCountdown(until: response.expiresAt)
            } catch {
                flowLog("[Flow][Pairing] generateCode failed: \(error)")
                errorMessage = "Couldn't generate a code: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    func reset() {
        flowLog("[Flow][Pairing] reset: start")
        countdownTask?.cancel()
        countdownTask = nil
        pairingCode = nil
        remainingSeconds = 0
        errorMessage = nil

        Task {
            do {
                try await self.backend.leaveDeviceGroup()
                flowLog("[Flow][Pairing] reset: leaveDeviceGroup succeeded")
            } catch {
                flowLog("[Flow][Pairing] reset: leaveDeviceGroup FAILED error=\(error)")
            }
            RemoteConnectionManager.shared.disconnect()
            ConnectionManager.shared.clearTrustedPeers()
            FlowDeviceIdentity.shared.clear()
            await SupabaseManager.shared.signOut()
            flowLog("[Flow][Pairing] reset: complete")
        }
    }

    private func startCountdown(until expiresAt: Date) {
        flowLog("[Flow][Pairing] startCountdown: until \(expiresAt)")
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let remaining = Int(expiresAt.timeIntervalSinceNow)
                guard remaining > 0 else {
                    flowLog("[Flow][Pairing] startCountdown: expired, clearing pairing code")
                    self.pairingCode = nil
                    self.remainingSeconds = 0
                    return
                }
                self.remainingSeconds = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}

#endif
