import Foundation
import Combine

@MainActor
final class RemotePairingViewModel: ObservableObject {
    static let shared = RemotePairingViewModel()

    @Published private(set) var pairingCode: String?
    @Published private(set) var remainingSeconds: Int = 0
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?

    private var expiryTask: Task<Void, Never>?

    func generateCode() {
        guard !isBusy else { return }
        isBusy = true
        errorMessage = nil
        Task {
            await performGenerateCode()
            isBusy = false
        }
    }

    private func performGenerateCode() async {
        let identity = FlowDeviceIdentity.shared
        _ = await SupabaseManager.shared.ensureSignedIn()

        if !identity.isRegistered {
            let deviceID = UUID()
            let secret = identity.generateDeviceSecret()

            guard let device = try? await FlowBackendClient.shared.registerDevice(
                deviceUUID: deviceID,
                deviceName: Host.current().localizedName ?? ProcessInfo.processInfo.hostName,
                platform: "Mac",
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                deviceSecret: secret
            ) else {
                errorMessage = "Couldn't register this Mac. Check your connection and try again."
                return
            }

            guard let groupID = try? await FlowBackendClient.shared.fetchCurrentGroupID() else {
                errorMessage = "Registered, but couldn't fetch the pairing group."
                return
            }

            identity.deviceID = device.id
            identity.deviceSecret = secret
            identity.role = "owner"
            identity.groupID = groupID
        }

        guard let secret = identity.deviceSecret else {
            errorMessage = "Missing device credentials. Try again."
            return
        }

        guard let result = try? await FlowBackendClient.shared.createPairingCode(deviceSecret: secret) else {
            errorMessage = "Couldn't generate a pairing code. Try again."
            return
        }

        pairingCode = result.code
        RemoteConnectionManager.shared.startAutoConnect()
        scheduleExpiry(at: result.expiresAt)
    }

    private func scheduleExpiry(at date: Date) {
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let remaining = Int(date.timeIntervalSinceNow.rounded(.up))
                self.remainingSeconds = max(0, remaining)
                if remaining <= 0 {
                    self.pairingCode = nil
                    break
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}