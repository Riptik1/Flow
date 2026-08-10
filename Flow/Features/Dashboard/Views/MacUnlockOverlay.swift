//
//  MacUnlockOverlay.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/06/26.
//

import SwiftUI

struct MacUnlockOverlay: View {
    let factory: FlowViewModelFactory
    @StateObject private var vm: MacUnlockViewModel
    @ObservedObject private var connection = FlowConnectionRepository.shared

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makeMacUnlockViewModel())
    }

    var body: some View {
        ZStack {
            blurBackground

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 20) {
                    profileView
                    userNameLabel

                    ZStack {
                        if vm.showError {
                            errorBadge
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                    .frame(height: 34)
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: vm.showError)

                    if vm.isAwake {
                        passwordInputArea
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                        submitButton
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .opacity
                            ))
                    } else {
                        wakeButton.transition(.opacity)
                    }
                }
                .padding(.horizontal, 52)

                Spacer()

                Text("Typing on iPhone goes directly into Mac password field")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.white.opacity(0.28))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .opacity(vm.isAwake ? 1 : 0)
                    .padding(.bottom, 40)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.82), value: vm.isAwake)
        .onAppear { vm.resetState() }
    }

    private var blurBackground: some View {
        ZStack {
            Color.black.opacity(0.01).ignoresSafeArea()
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color.black.opacity(0.30).ignoresSafeArea()
        }
    }

    private var profileView: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 108, height: 108)
                .shadow(color: .black.opacity(0.5), radius: 24, x: 0, y: 12)
                .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 3)

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 108, height: 108)

            if let imageData = connection.macProfileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
            } else {
                initialsView
            }
        }
    }

    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 0.28, green: 0.44, blue: 0.72),
                             Color(red: 0.16, green: 0.28, blue: 0.52)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 100, height: 100)
            Text(initials)
                .font(.system(size: 36, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    private var initials: String {
        let name = connection.connectedPeer?.userName ?? ""
        let parts = name.split(separator: " ").prefix(2)
        if parts.isEmpty { return "?" }
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    private var userNameLabel: some View {
        VStack(spacing: 4) {
            Text(connection.connectedPeer?.userName ?? "Mac User")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
            Text(connection.connectedPeer?.deviceName ?? "MacBook")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var errorBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 12, weight: .medium))
            Text("Incorrect Password")
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(Color(red: 1.0, green: 0.38, blue: 0.38))
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.18))
                .overlay(Capsule().strokeBorder(
                    Color(red: 1.0, green: 0.3, blue: 0.3).opacity(0.35), lineWidth: 0.8))
        )
    }

    private var wakeButton: some View {
        Button {
            vm.wake()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "power.circle.fill")
                    .font(.system(size: 18, weight: .medium))
                Text("Wake Mac")
                    .font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.18))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.30), lineWidth: 0.8))
            )
        }
        .buttonStyle(.plain)
    }

    private var passwordInputArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(vm.fieldFocused ? 0.16 : 0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            vm.fieldFocused ? Color.white.opacity(0.45) : Color.white.opacity(0.20),
                            lineWidth: vm.fieldFocused ? 1.2 : 0.8
                        )
                )
                .animation(.easeInOut(duration: 0.2), value: vm.fieldFocused)

            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(width: 18)

                MacPasswordTextField(
                    charCount: vm.charCount,
                    isFocused: vm.fieldFocused,
                    onCharacterAdded: { char in vm.appendCharacter(char) },
                    onBackspace: { vm.backspace() },
                    onSubmit: { vm.submitPassword() }
                )
                .frame(height: 22)

                if vm.charCount > 0 && !vm.isSubmitting {
                    Button {
                        vm.clearAll()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(.white.opacity(0.45))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .frame(height: 48)
        .offset(x: vm.shakeOffset)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: vm.shakeOffset)
        .onTapGesture { vm.fieldFocused = true }
    }

    private var submitButton: some View {
        Button { vm.submitPassword() } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        (vm.charCount == 0 || vm.isSubmitting)
                            ? Color.white.opacity(0.12)
                            : Color.white.opacity(0.22)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 0.8))

                if vm.isSubmitting {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white).scaleEffect(0.75)
                        Text("Unlocking…")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                } else {
                    Text("Unlock")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(vm.charCount == 0 ? .white.opacity(0.35) : .white)
                }
            }
            .frame(height: 48)
        }
        .buttonStyle(.plain)
        .disabled(vm.charCount == 0 || vm.isSubmitting)
    }
}
