//
//  SidebarView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 17/05/26.
//

import SwiftUI

struct FileSidebarView: View {
    @ObservedObject var store: FileStore
    let factory: FlowViewModelFactory
    var isCompact: Bool = false
    @State private var selectedItem: SidebarItem? = nil

    private let red = Color(red: 0.76, green: 0.08, blue: 0.08)

    var body: some View {
        List {
            ForEach(SidebarSection.all) { section in
                if let title = section.title {
                    Section {
                        sidebarRows(section.items)
                    } header: {
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .textCase(.none)
                            .padding(.top, 4)
                    }
                } else {
                    sidebarRows(section.items)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Files")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(.label))
            }
        }
    }

    @ViewBuilder
    private func sidebarRows(_ items: [SidebarItem]) -> some View {
        ForEach(items) { item in
            if isCompact {
                NavigationLink {
                    destinationView(for: item)
                } label: {
                    FileSidebarRowView(item: item, isSelected: false, red: red)
                }
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(Color(.separator).opacity(0.4))
            } else {
                Button {
                    selectedItem = item
                    handleSelection(item)
                } label: {
                    FileSidebarRowView(item: item, isSelected: selectedItem == item, red: red)
                }
                .buttonStyle(.plain)
                .transaction { $0.animation = nil }
                .listRowBackground(
                    selectedItem == item
                        ? RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(red.opacity(0.1))
                            .padding(.horizontal, 4)
                        : nil
                )
            }
        }
    }

    @ViewBuilder
    private func destinationView(for item: SidebarItem) -> some View {
        switch item.id {
        case .recents:
            FileListView(title: "Recents", path: "", store: store, mode: .recents, factory: factory)
        default:
            FileListView(title: item.title, path: pathForItem(item), store: store, mode: .directory, factory: factory)
        }
    }

    private func handleSelection(_ item: SidebarItem) {
        switch item.id {
        case .recents:
            store.loadDirectory("")
        default:
            store.loadDirectory(pathForItem(item))
        }
    }

    private func pathForItem(_ item: SidebarItem) -> String {
        switch item.id {
        case .documents:    return "~/Documents"
        case .desktop:      return "~/Desktop"
        case .downloads:    return "~/Downloads"
        case .home:         return "~"
        case .applications: return "/Applications"
        case .macintoshHD:  return "/"
        default:            return "~"
        }
    }
}

struct FileSidebarRowView: View {
    let item: SidebarItem
    let isSelected: Bool
    let red: Color

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: item.systemImage)
                .foregroundStyle(isSelected ? red : Color(.secondaryLabel))
                .font(.system(size: 15))
                .frame(width: 26, alignment: .center)
            Text(item.title)
                .foregroundStyle(isSelected ? red : Color(.label))
                .font(.system(size: 15))
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}
