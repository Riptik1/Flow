//
//  GCard.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI

struct GCard: View {
    let icon: String; let color: Color; let title: String; let badge: String; let desc: String
    @Environment(\.colorScheme) private var cs
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color.opacity(cs == .dark ? 0.20 : 0.10))
                    .frame(width: isIPad ? 52 : 44, height: isIPad ? 52 : 44)
                Image(systemName: icon)
                    .font(.system(size: isIPad ? 21 : 17, weight: .medium)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(title).font(.system(size: isIPad ? 15 : 14, weight: .semibold))
                    Text(badge).font(.system(size: isIPad ? 10 : 9, weight: .semibold)).foregroundStyle(color)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Capsule().fill(color.opacity(cs == .dark ? 0.18 : 0.10)))
                }
                Text(desc).font(.system(size: isIPad ? 13 : 12)).foregroundStyle(.secondary).lineSpacing(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(cs == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.025))
                .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(cs == .dark ? Color.white.opacity(0.07) : Color.black.opacity(0.05), lineWidth: 0.8)))
    }
}

struct TipRow: View {
    let icon: String; let color: Color; let text: String
    @Environment(\.colorScheme) private var cs
    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: isIPad ? 13 : 11, weight: .semibold)).foregroundStyle(color)
                .frame(width: isIPad ? 30 : 26, height: isIPad ? 30 : 26)
                .background(Circle().fill(color.opacity(cs == .dark ? 0.18 : 0.10)))
            Text(text).font(.system(size: isIPad ? 14 : 13)).foregroundStyle(.secondary).lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true).padding(.top, isIPad ? 6 : 5)
            Spacer(minLength: 0)
        }
    }
}
