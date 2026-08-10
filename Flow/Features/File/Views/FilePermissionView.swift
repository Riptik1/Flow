//
//  FilePermissionView.swift
//  Flow
//
//  Created by Assistant on 24/05/26.
//

import SwiftUI

struct FilePermissionView: View {
    @ObservedObject var store: FileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.shield")
                .font(.system(size: 64, weight: .ultraLight))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Permissions Required")
                    .font(.title2.bold())

                Text("Your Mac must grant system access so Flow can browse, preview, and manage files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(alignment: .leading, spacing: 20) {
                PermissionRow(icon: "externaldrive.fill", title: "Full Disk Access", description: "Browse all files and protected folders")
                PermissionRow(icon: "terminal.fill", title: "Automation", description: "Control Finder and system applications")
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)

            if !store.missingPermissions.isEmpty {
                Text("Missing: \(store.missingPermissions.joined(separator: " · "))")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: { store.checkPermissions() }) {
                    HStack(spacing: 8) {
                        if store.isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(store.permissionGranted ? "Continue to Files" : "Check Permissions")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Capsule().fill(store.permissionGranted ? Color.green : Color.blue))
                }
                .disabled(store.isLoading)

                if !store.permissionGranted {
                    Text("Open System Settings on your Mac and enable the permissions above, then tap Check Permissions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .onChange(of: store.permissionGranted) { granted in
            if granted { dismiss() }
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.blue)
                .frame(width: 36, height: 36)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}