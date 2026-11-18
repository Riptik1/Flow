import SwiftUI

struct RemotePairingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var code: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var timeoutTask: Task<Void, Never>?
    @ObservedObject private var connection = FlowConnectionRepository.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "personalhotspot")
                        .font(.system(size: 34, weight: .light))
                        .foregroundStyle(.blue)
                    Text("Connect to Your Mac")
                        .font(.system(size: 20, weight: .bold))
                    Text("On your Mac, click “Generate Pairing Code”, then type the code here.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 20)

                TextField("Pairing Code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.06)))
                    .padding(.horizontal, 24)

                if isSubmitting {
                    Text(progressLabel)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.red)
                }

                Button(action: submit) {
                    HStack(spacing: 8) {
                        if isSubmitting { ProgressView().controlSize(.small).tint(.white) }
                        Text(isSubmitting ? "Connecting…" : "Connect")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
                .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)

                Button(action: resetDevice) {
                    Text("Reset this device's pairing")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)

                Spacer()
            }
            .padding(.top, 12)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .onChange(of: connection.pairingCompletionToken) { _, _ in
            // Fires when the Mac accepted the code – also when the phone is already
            // connected over Wi-Fi and the remote link is only stored for later.
            if isSubmitting {
                finish(success: true, message: nil)
            }
        }
        .onChange(of: connection.state) { _, newState in
            if newState == .connected, isSubmitting {
                finish(success: true, message: nil)
            }
        }
        .onChange(of: connection.pairingError) { _, newError in
            if let newError, isSubmitting {
                finish(success: false, message: newError)
            }
        }
    }

    private var progressLabel: String {
        switch connection.state {
        case .disconnected: return "Validating code…"
        case .searching: return "Joining your Mac's group…"
        case .connecting: return "Reaching your Mac…"
        case .connected: return "Connected"
        }
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        connection.redeem(code: code.trimmingCharacters(in: .whitespaces).uppercased())

        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            guard !Task.isCancelled else { return }
            if connection.state != .connected {
                finish(success: false, message: connection.pairingError ?? "Couldn't connect. Check the code and try again.")
            }
        }
    }

    private func resetDevice() {
        timeoutTask?.cancel()
        timeoutTask = nil
        isSubmitting = false
        errorMessage = nil
        FlowDeviceIdentity.shared.clear()
        RemoteConnectionManager.shared.disconnect()
        Task {
            try? await FlowBackendClient.shared.leaveDeviceGroup()
            await SupabaseManager.shared.signOut()
        }
    }

    private func finish(success: Bool, message: String?) {
        timeoutTask?.cancel()
        timeoutTask = nil
        isSubmitting = false
        errorMessage = message
        if success {
            dismiss()
        }
    }
}
