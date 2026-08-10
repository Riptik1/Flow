//
//  ReconnectingOverlay.swift
//  Flow
//
//  Created by Riptik Jhajhria on 07/07/26.
//


import SwiftUI

struct ReconnectingOverlay: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text("Mac is offline")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Make sure Flow is open on your Mac. We'll reconnect automatically.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Waiting…")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(scheme == .dark
                                  ? Color(red: 0.09, green: 0.09, blue: 0.13).opacity(0.82)
                                  : Color.white.opacity(0.75))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(scheme == .dark ? 0.16 : 0.65), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(0.45), radius: 48, x: 0, y: 24)
            )
            .padding(.horizontal, 40)
        }
    }
}