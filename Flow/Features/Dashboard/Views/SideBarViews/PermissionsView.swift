//
//  PermissionsView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 09/06/26.
//


import SwiftUI
import AVFoundation
import UserNotifications
import LocalAuthentication
import CoreBluetooth

struct PermissionsView: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @ObservedObject private var connection = ConnectionManager.shared
    @State private var cameraAuthorized = false
    @State private var microphoneAuthorized = false
    @State private var notificationsAuthorized = false
    @State private var faceIDAvailable = false
    @State private var bluetoothAuthorized = false
    @State private var localNetworkAuthorized = false
    @State private var showFaceIDAlert = false
    @State private var showLocalNetworkAlert = false

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
                        icon: "wifi",
                        title: "Local Network",
                        subtitle: "Required to discover and connect to your Mac",
                        isOn: localNetworkAuthorized,
                        color: .blue
                    ) { handleLocalNetwork() }

                    PermissionRow(
                        icon: "bell.fill",
                        title: "Notifications",
                        subtitle: "Receive alerts for connection status and updates",
                        isOn: notificationsAuthorized,
                        color: .orange
                    ) { handleNotifications() }

                    PermissionRow(
                        icon: "camera.fill",
                        title: "Camera",
                        subtitle: "Used for QR code pairing with your Mac",
                        isOn: cameraAuthorized,
                        color: .green
                    ) { handleCamera() }

                    PermissionRow(
                        icon: "mic.fill",
                        title: "Microphone",
                        subtitle: "Required for voice commands and audio control",
                        isOn: microphoneAuthorized,
                        color: .red
                    ) { handleMicrophone() }

                    PermissionRow(
                        icon: "faceid",
                        title: "Face ID",
                        subtitle: "Securely unlock your Mac using biometrics",
                        isOn: faceIDAvailable,
                        color: .purple
                    ) { handleFaceID() }

                    PermissionRow(
                        icon: "bolt.horizontal.fill",
                        title: "Bluetooth",
                        subtitle: "Discover nearby devices via Bluetooth",
                        isOn: bluetoothAuthorized,
                        color: .cyan
                    ) { handleBluetooth() }
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 40)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Permissions")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: checkAllPermissions)
        .alert("Face ID Unavailable", isPresented: $showFaceIDAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Face ID is not set up on this device. Please configure it in Settings.")
        }
        .alert("Local Network Access", isPresented: $showLocalNetworkAlert) {
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Flow needs Local Network access to discover your Mac. Please enable it in Settings.")
        }
    }

    private func checkAllPermissions() {
        checkCamera()
        checkMicrophone()
        checkNotifications()
        checkFaceID()
        checkBluetooth()
        checkLocalNetwork()
    }

    private func checkCamera() {
        cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    private func checkMicrophone() {
        microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func checkNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    private func checkFaceID() {
        let context = LAContext()
        var error: NSError?
        faceIDAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private func checkBluetooth() {
        bluetoothAuthorized = CBCentralManager.authorization == .allowedAlways
    }

    private func checkLocalNetwork() {
        localNetworkAuthorized = false
    }

    private func handleNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                        DispatchQueue.main.async { self.checkNotifications() }
                    }
                default:
                    self.openSettings()
                }
            }
        }
    }

    private func handleCamera() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { _ in
                DispatchQueue.main.async { self.checkCamera() }
            }
        default:
            openSettings()
        }
    }

    private func handleMicrophone() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { _ in
                DispatchQueue.main.async { self.checkMicrophone() }
            }
        default:
            openSettings()
        }
    }

    private func handleFaceID() {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if canEvaluate {
            openSettings()
        } else {
            showFaceIDAlert = true
        }
    }

    private func handleBluetooth() {
        let status = CBCentralManager.authorization
        switch status {
        case .notDetermined:
            _ = CBCentralManager()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.checkBluetooth() }
        default:
            openSettings()
        }
    }

    private func handleLocalNetwork() {
        showLocalNetworkAlert = true
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
    @Environment(\.colorScheme) private var scheme

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