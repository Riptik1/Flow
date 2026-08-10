//
//  SidebarView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 17/05/26.
//


import SwiftUI

struct FileSidebarView: View {
    @Binding var selectedItem: SidebarItem?

    private let background = Color(red: 0.11, green: 0.11, blue: 0.13)

    var body: some View {
        List(selection: $selectedItem) {
            ForEach(SidebarSection.all) { section in
                if let title = section.title {
                    Section {
                        sidebarRows(section.items)
                    } header: {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.gray)
                            .textCase(.none)
                    }
                } else {
                    sidebarRows(section.items)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(background)
        .navigationTitle("Files")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func sidebarRows(_ items: [SidebarItem]) -> some View {
        ForEach(items) { item in
            FileSidebarRowView(item: item, isSelected: selectedItem == item)
                .tag(item)
                .listRowBackground(
                    selectedItem == item
                        ? Color.white.opacity(0.07)
                        : Color.clear
                )
        }
    }
}

struct FileSidebarRowView: View {
    let item: SidebarItem
    let isSelected: Bool

    private var foreground: Color {
        isSelected ? Color(red: 0.76, green: 0.08, blue: 0.08) : .white
    }

    private var iconForeground: Color {
        isSelected ? Color(red: 0.76, green: 0.08, blue: 0.08) : item.accentColor
    }

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: item.systemImage)
                .foregroundStyle(iconForeground)
                .font(.system(size: 15, weight: .regular))
                .frame(width: 24, alignment: .center)

            Text(item.title)
                .foregroundStyle(foreground)
                .font(.system(size: 15))
                .lineLimit(1)
        }
        .padding(.vertical, 3)
    }
}
