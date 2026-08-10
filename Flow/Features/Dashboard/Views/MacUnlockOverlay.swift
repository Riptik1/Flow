import SwiftUI

struct MacUnlockOverlay: View {
    @StateObject private var connection = ConnectionManager.shared
    @State private var password: String = ""
    @State private var isKeyboardVisible: Bool = false
    @State private var isUnlocking: Bool = false
    @State private var shakeOffset: CGFloat = 0
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            VisualEffectBackground()
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                profileImageView

                userNameView

                passwordField

                Spacer()
            }
            .padding(.horizontal, 40)
        }
        .onReceive(connection.messageStream) { message in
            switch message {
            case .unlockSuccess:
                withAnimation(.easeInOut(duration: 0.3)) {
                    isUnlocking = false
                }
            case .unlockFailed:
                withAnimation(.easeInOut(duration: 0.3)) {
                    isUnlocking = false
                    triggerShake()
                }
            default:
                break
            }
        }
    }

    private var profileImageView: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.35, green: 0.55, blue: 0.85),
                            Color(red: 0.20, green: 0.35, blue: 0.60)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 100, height: 100)
                .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: 10)

            if let imageData = connection.connectedPeer?.profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(Circle())
                    .frame(width: 100, height: 100)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    private var userNameView: some View {
        Text(connection.connectedPeer?.userName ?? NSFullUserName())
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(.primary)
    }

    private var passwordField: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                if isKeyboardVisible {
                    TextField("Password", text: $password)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.go)
                        .onSubmit {
                            attemptUnlock()
                        }
                } else {
                    SecureField("Password", text: $password)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.go)
                        .onSubmit {
                            attemptUnlock()
                        }
                }

                if !password.isEmpty {
                    Button {
                        password = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(scheme == .dark ? 0.12 : 0.50), lineWidth: 0.8)
                    )
            )
            .offset(x: shakeOffset)
            .onTapGesture {
                isKeyboardVisible = true
            }

            Button {
                attemptUnlock()
            } label: {
                HStack(spacing: 8) {
                    if isUnlocking {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                    }
                    Text("Unlock")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(password.isEmpty ? Color.blue.opacity(0.4) : Color.blue)
                )
            }
            .disabled(password.isEmpty || isUnlocking)
            .buttonStyle(.plain)
        }
    }

    private func attemptUnlock() {
        guard !password.isEmpty, !isUnlocking else { return }
        isUnlocking = true
        connection.send(.unlockMac(password: password))
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func triggerShake() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)

        withAnimation(.easeInOut(duration: 0.05)) {
            shakeOffset = -10
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.05)) {
                shakeOffset = 10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
            withAnimation(.easeInOut(duration: 0.05)) {
                shakeOffset = -10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.05)) {
                shakeOffset = 10
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.easeInOut(duration: 0.05)) {
                shakeOffset = 0
            }
        }
    }
}