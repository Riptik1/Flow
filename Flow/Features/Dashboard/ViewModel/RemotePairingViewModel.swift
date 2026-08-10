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
            print("[Flow][Pairing] generateCode: already busy, ignoring tap")
            return
        }
        print("[Flow][Pairing] generateCode: start")
        isBusy = true
        errorMessage = nil

        Task {
            do {
                print("[Flow][Pairing] generateCode: ensuring device is registered")
                try await RemoteConnectionManager.shared.ensureRegistered()
                print("[Flow][Pairing] generateCode: registered, requesting code from backend")
                let response = try await backend.generatePairingCode()
                print("[Flow][Pairing] generateCode: got code=\(response.code) expiresAt=\(response.expiresAt)")
                pairingCode = response.code
                startCountdown(until: response.expiresAt)
            } catch {
                print("[Flow][Pairing] generateCode failed: \(error)")
                errorMessage = "Couldn't generate a code: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    func reset() {
        print("[Flow][Pairing] reset: start")
        countdownTask?.cancel()
        countdownTask = nil
        pairingCode = nil
        remainingSeconds = 0
        errorMessage = nil

        Task {
            do {
                try await self.backend.leaveDeviceGroup()
                print("[Flow][Pairing] reset: leaveDeviceGroup succeeded")
            } catch {
                print("[Flow][Pairing] reset: leaveDeviceGroup FAILED error=\(error)")
            }
            RemoteConnectionManager.shared.disconnect()
            FlowDeviceIdentity.shared.clear()
            await SupabaseManager.shared.signOut()
            print("[Flow][Pairing] reset: complete")
        }
    }

    private func startCountdown(until expiresAt: Date) {
        print("[Flow][Pairing] startCountdown: until \(expiresAt)")
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let remaining = Int(expiresAt.timeIntervalSinceNow)
                guard remaining > 0 else {
                    print("[Flow][Pairing] startCountdown: expired, clearing pairing code")
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
