//
//  FirstLaunchSetupView.swift
//  Flow
//
//  Shown once after install so the permissions Flow needs are granted up front.
//

import SwiftUI

struct FirstLaunchSetupView: View {
    let onFinish: () -> Void

    @StateObject private var vm = PermissionsViewModel()
    @ObservedObject private var connection = FlowConnectionRepository.shared
    @ObservedObject private var localNetwork = LocalNetworkPermission.shared
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSkipWarning = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Set up Flow")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Allow these so Flow can find your Mac.")
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    VStack(spacing: 12) {
                        PermissionRow(
                            icon: "wifi", title: "Local Network",
                            subtitle: "Needed to find your Mac on Wi-Fi",
                            isOn: vm.localNetworkAuthorized, color: .blue
                        ) { vm.handleLocalNetwork() }

                        PermissionRow(
                            icon: "antenna.radiowaves.left.and.right", title: "Wi-Fi",
                            subtitle: connection.isOnWiFi
                                ? "Connected. Use the same network as your Mac."
                                : "Turn on Wi-Fi and join your Mac's network.",
                            isOn: connection.isOnWiFi, color: .green
                        ) { openSettings() }

                        PermissionRow(
                            icon: "bell.fill", title: "Notifications",
                            subtitle: "Get connection alerts",
                            isOn: vm.notificationsAuthorized, color: .orange
                        ) { vm.handleNotifications(openSettings: openSettings) }
                    }
                    .padding(.horizontal, 20)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Open Flow on your Mac too", systemImage: "laptopcomputer")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)

                    Button(action: continueTapped) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                }
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .onAppear {
            vm.checkAllPermissions()
            // Ask for Local Network right away – it is the one permission Flow cannot work without.
            LocalNetworkPermission.shared.check()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { vm.checkAllPermissions() }
        }
        .alert("Local Network is off", isPresented: $showSkipWarning) {
            Button("Open Settings") { openSettings() }
            Button("Continue Anyway", role: .cancel) { onFinish() }
        } message: {
            Text("Flow can't find your Mac on Wi-Fi without it.")
        }
    }

    private func continueTapped() {
        if vm.localNetworkAuthorized {
            onFinish()
        } else {
            showSkipWarning = true
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
    }
}
