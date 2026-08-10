//
//  ClipboardView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI

struct ClipboardView: View {
    let factory: FlowViewModelFactory
    @StateObject private var vm: ClipboardViewModel
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var toast: String? = nil
    @Environment(\.colorScheme) private var cs

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makeClipboardViewModel())
    }

    private var displayItems: [ClipboardItem] {
        guard !searchText.isEmpty else { return vm.items }
        return vm.items.filter {
            $0.text?.localizedCaseInsensitiveContains(searchText) == true ||
            $0.contentType.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func makePairs(_ list: [ClipboardItem]) -> [ClipboardViewModel.ItemPair] {
        var result: [ClipboardViewModel.ItemPair] = []
        var i = 0
        while i < list.count {
            let right: ClipboardItem? = (i + 1 < list.count) ? list[i + 1] : nil
            result.append(ClipboardViewModel.ItemPair(id: i, left: list[i], right: right))
            i += 2
        }
        return result
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                if showSearch {
                    searchBar
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                mainContent
            }

            if let msg = toast {
                Text(msg)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22).padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(Color(white: 0.10).opacity(0.95))
                            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 5)
                    )
                    .padding(.bottom, 32)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Clipboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showSearch.toggle()
                        if !showSearch { searchText = "" }
                    }
                } label: {
                    Image(systemName: showSearch ? "xmark" : "magnifyingglass")
                        .font(.system(size: 15, weight: .medium))
                }
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: toast)
        .animation(.easeInOut(duration: 0.2), value: showSearch)
        .onAppear { vm.onAppear() }
    }

    @ViewBuilder
    private var mainContent: some View {
        if vm.items.isEmpty && vm.isRefreshing {
            Spacer()
            ProgressView().scaleEffect(1.2)
            Text("Loading…").font(.system(size: 14)).foregroundStyle(.secondary).padding(.top, 10)
            Spacer()
        } else if displayItems.isEmpty {
            emptyView
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(makePairs(displayItems)) { pair in
                        HStack(alignment: .top, spacing: 8) {
                            clipRow(pair.left)
                            if let right = pair.right {
                                clipRow(right)
                            } else {
                                Color.clear.frame(maxWidth: .infinity)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
        }
    }

    private func clipRow(_ item: ClipboardItem) -> some View {
        ClipCard(item: item)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contextMenu {
                Button {
                    vm.copyToiPhone(item)
                    showToast("Copied!")
                } label: {
                    Label("Copy", systemImage: "doc.on.doc.fill")
                }
                Button {
                    vm.pasteToMac(item)
                    showToast("Pasted to Mac!")
                } label: {
                    Label("Paste to Mac", systemImage: "macwindow")
                }
                Divider()
                Button(role: .destructive) {
                    vm.deleteItem(item)
                } label: {
                    Label("Delete", systemImage: "trash.fill")
                }
            } preview: {
                ClipCard(item: item)
                    .frame(width: 240)
                    .padding(2)
                    .background(Color(uiColor: .systemBackground))
            }
            .onTapGesture {
                vm.copyToiPhone(item)
                showToast("Copied!")
            }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 14, weight: .medium))
            TextField("Search clipboard…", text: $searchText)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(cs == .dark ? 0.08 : 0.06))
        )
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 4)
    }

    private var emptyView: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(cs == .dark ? Color(white: 0.14) : Color(white: 0.90))
                    .frame(width: 68, height: 68)
                Image(systemName: searchText.isEmpty ? "doc.on.clipboard" : "magnifyingglass")
                    .font(.system(size: 26, weight: .light)).foregroundStyle(.secondary)
            }
            Text(searchText.isEmpty ? "No clipboard history" : "No results")
                .font(.system(size: 16, weight: .semibold))
            Text(searchText.isEmpty ? "Copy something on your Mac\nand it will appear here" : "Try a different search term")
                .font(.system(size: 13)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if searchText.isEmpty {
                Button { vm.refresh() } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                }.buttonStyle(.plain).padding(.top, 4)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 32)
    }

    private func showToast(_ msg: String) {
        withAnimation { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { withAnimation { toast = nil } }
    }
}

private struct ClipCard: View {
    let item: ClipboardItem
    @Environment(\.colorScheme) private var cs

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(item.contentType.iconColor)
                        .frame(width: 28, height: 28)
                    Image(systemName: item.contentType.iconSymbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.contentType.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(timeAgo)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            previewContent
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(height: 72)
                .clipped()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cs == .dark ? Color(white: 0.33) : Color(white: 0.96))
        )
        .shadow(color: .black.opacity(cs == .dark ? 0.55 : 0.18), radius: 8, x: 6, y: 9)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch item.contentType {
        case .image:
            if let data = item.imageData, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 72)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        case .code, .json, .sql, .markdown:
            Text(item.text ?? "")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(cs == .dark ? Color(white: 0.75) : Color(white: 0.25))
                .lineLimit(5).lineSpacing(2)
                .frame(maxWidth: .infinity, maxHeight: 72, alignment: .topLeading)
                .padding(.horizontal, 7).padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(cs == .dark ? Color(white: 0.08) : Color(white: 0.88))
                )
        case .url:
            HStack(alignment: .top, spacing: 4) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Color(red: 0.20, green: 0.55, blue: 0.95))
                    .padding(.top, 1)
                Text(item.text ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.20, green: 0.55, blue: 0.95))
                    .lineLimit(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(7)
            .frame(maxWidth: .infinity, maxHeight: 72, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.20, green: 0.55, blue: 0.95).opacity(cs == .dark ? 0.12 : 0.08))
            )
        default:
            Text(item.text ?? "")
                .font(.system(size: 12))
                .foregroundStyle(.primary.opacity(0.82))
                .lineLimit(5).lineSpacing(2)
                .frame(maxWidth: .infinity, maxHeight: 72, alignment: .topLeading)
        }
    }

    private var timeAgo: String {
        let e = Date().timeIntervalSince1970 - item.timestamp
        if e < 60    { return "Just now" }
        if e < 3600  { return "\(Int(e/60))m ago" }
        if e < 86400 { return "\(Int(e/3600))h ago" }
        return "\(Int(e/86400))d ago"
    }
}
