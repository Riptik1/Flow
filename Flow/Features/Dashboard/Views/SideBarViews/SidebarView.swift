//
//  SidebarView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 11/05/26.
//

import SwiftUI

struct SidebarView: View {
    @State private var selected = "Dashboard"
    @Environment(\.colorScheme) private var scheme
    var onSelect: (String) -> Void = { _ in }

    private let items: [(String, String)] = [
        ("Dashboard",    "house.fill"),
        ("Subscription", "crown.fill"),
        ("Devices",      "macbook")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image("AppIcon")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("Flow")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 64)
            .padding(.bottom, 24)

            VStack(spacing: 6) {
                ForEach(items, id: \.0) { item in
                    SidebarRow(title: item.0, icon: item.1, isSelected: selected == item.0) {
                        withAnimation(.snappy(duration: 0.2)) {
                            selected = item.0
                        }
                        onSelect(item.0)
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()
        }
        .frame(width: 270)
        .background(Color(uiColor: .systemBackground))
        .onAppear {
            selected = "Dashboard"
        }
    }
}

struct SidebarRow: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .frame(width: 24)
                    .foregroundStyle(isSelected ? Color.blue : .secondary)

                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.blue.opacity(scheme == .dark ? 0.15 : 0.08))
                }
            }
        }
        .buttonStyle(.plain)
    }
}
