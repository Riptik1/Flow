//
//  PermissionsView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 09/06/26.
//

import SwiftUI

struct PermissionsView: View {
    let factory: FlowViewModelFactory
    @StateObject private var vm: PermissionsViewModel
    @Environment(\.openURL) private var openURL

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makePermissionsViewModel())
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Permissions")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Enable these for Flow to work properly")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)

                VStack(spacing: 12) {
                    PermissionRow(
                        icon: "wifi", title: "Local Network",
                        subtitle: "Required to discover and connect to your Mac",
                        isOn: vm.localNetworkAuthorized, color: .blue
                    ) { vm.handleLocalNetwork() }

                    PermissionRow(
                        icon: "bell.fill", title: "Notifications",
                        subtitle: "Receive alerts for connection status and updates",
                        isOn: vm.notificationsAuthorized, color: .orange
                    ) { vm.handleNotifications(openSettings: openSettings) }

                    PermissionRow(
                        icon: "camera.fill", title: "Camera",
                        subtitle: "Used for QR code pairing with your Mac",
                        isOn: vm.cameraAuthorized, color: .green
                    ) { vm.handleCamera(openSettings: openSettings) }

                    PermissionRow(
                        icon: "mic.fill", title: "Microphone",
                        subtitle: "Required for voice commands and audio control",
                        isOn: vm.microphoneAuthorized, color: .red
                    ) { vm.handleMicrophone(openSettings: openSettings) }

                    PermissionRow(
                        icon: "faceid", title: "Face ID",
                        subtitle: "Securely unlock your Mac using biometrics",
                        isOn: vm.faceIDAvailable, color: .purple
                    ) { vm.handleFaceID(openSettings: openSettings) }

                    PermissionRow(
                        icon: "bolt.horizontal.fill", title: "Bluetooth",
                        subtitle: "Discover nearby devices via Bluetooth",
                        isOn: vm.bluetoothAuthorized, color: .cyan
                    ) { vm.handleBluetooth(openSettings: openSettings) }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { vm.checkAllPermissions() }
        .alert("Face ID Unavailable", isPresented: $vm.showFaceIDAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID is not set up on this device. Please configure it in Settings.")
        }
        .alert("Local Network Access", isPresented: $vm.showLocalNetworkAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Flow needs Local Network access to discover your Mac. Please enable it in Settings.")
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isOn: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        GlassCard(cornerRadius: 14, padding: 16) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(color.opacity(0.12)))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Circle()
                    .fill(isOn ? color : Color.primary.opacity(0.1))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Image(systemName: isOn ? "checkmark" : "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isOn ? .white : .secondary)
                    )
            }
        }
        .onTapGesture(perform: action)
    }
}
