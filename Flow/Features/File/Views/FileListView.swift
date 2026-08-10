//
//  FileListView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 17/05/26.
//

import SwiftUI

struct FileListView: View {
    let title: String
    let path: String
    @ObservedObject var store: FileStore
    let mode: Mode
    let factory: FlowViewModelFactory
    enum Mode: Equatable { case directory, recents }

    @StateObject private var vm: FileListViewModel
    @State private var searchText = ""
    @State private var hasLoaded = false
    @State private var shareItem: ShareItem? = nil
    @State private var saveItem: ShareItem? = nil

    init(title: String, path: String, store: FileStore, mode: Mode, factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.title = title
        self.path = path
        self.store = store
        self.mode = mode
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makeFileListViewModel())
    }

    private static let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy, h:mm a"
        return f
    }()

    private var displayFiles: [FileItem] {
        guard !searchText.isEmpty else { return vm.files }
        return vm.files.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            fileList
            pendingOverlay
        }
        .animation(.easeInOut(duration: 0.15), value: vm.isPendingSave)
        .animation(.easeInOut(duration: 0.15), value: vm.isPendingShare)
        .animation(.easeInOut(duration: 0.15), value: vm.isPendingPreview)
        .fullScreenCover(item: previewBinding) { item in
            FilePreviewView(item: item, onOpenOnMac: { vm.openOnMac(item.sourcePath) })
                .id(item.id)
        }
        .sheet(item: $shareItem) { item in
            ShareSheetView(url: item.url)
        }
        .sheet(item: $saveItem) { item in
            DocumentSavePicker(url: item.url)
        }
        .onAppear {
            guard !hasLoaded else { return }
            hasLoaded = true
            loadData()
        }
        .onChange(of: path) { _, p in
            if mode == .directory { vm.load(path: p) }
        }
        .onChange(of: vm.pendingShareItem) { _, item in
            guard let item else { return }
            shareItem = item
            vm.consumeShareItem()
        }
        .onChange(of: vm.pendingSaveItem) { _, item in
            guard let item else { return }
            saveItem = item
            vm.consumeSaveItem()
        }
        .alert("Error", isPresented: errorAlertBinding) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Rename", isPresented: $vm.showRenameAlert) {
            TextField("New name", text: $vm.renameText)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let p = vm.renameTargetPath, !vm.renameText.isEmpty {
                    vm.renameFile(at: p, newName: vm.renameText)
                }
            }
        } message: {
            Text("Enter a new name")
        }
        .alert("File Too Large to Preview", isPresented: largeFileAlertBinding) {
            Button("Cancel", role: .cancel) { vm.largeFileAlert = nil }
            Button("Open on Mac") {
                if let info = vm.largeFileAlert { vm.openOnMac(info.filePath) }
                vm.largeFileAlert = nil
            }
        } message: {
            largeFileAlertMessage
        }
    }

    private var fileList: some View {
        List(displayFiles) { file in
            listRow(for: file)
                .contextMenu { contextMenuItems(for: file) }
                .listRowBackground(Color(.systemBackground))
                .listRowSeparatorTint(Color(.separator).opacity(0.4))
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        }
        .listStyle(.plain)
        .overlay { emptyOverlay }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search files…")
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
    }

    @ViewBuilder
    private func listRow(for file: FileItem) -> some View {
        if file.kind == .folder && mode == .directory {
            NavigationLink {
                FileListView(title: file.name, path: file.path, store: store, mode: .directory, factory: factory)
            } label: {
                FileRowCompact(file: file, formatter: Self.fmt)
            }
        } else {
            FileRowCompact(file: file, formatter: Self.fmt, isLoading: vm.pendingPreviewPath == file.path)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard vm.pendingResponse == .none else { return }
                    if file.kind == .video || file.kind == .audio {
                        vm.openOnMac(file.path)
                    } else {
                        vm.previewFile(file)
                    }
                }
        }
    }

    @ViewBuilder
    private func contextMenuItems(for file: FileItem) -> some View {
        if file.kind == .folder {
            Button { vm.openOnMac(file.path) } label: {
                Label("Open on Mac", systemImage: "arrow.up.right.square")
            }
            Button {
                vm.renameTargetPath = file.path
                vm.renameText = file.name
                vm.showRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Divider()
            Button(role: .destructive) { vm.deleteFile(file.path) } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        } else {
            Button { vm.openOnMac(file.path) } label: {
                Label("Open on Mac", systemImage: "arrow.up.right.square")
            }
            if file.kind != .video && file.kind != .audio {
                Button { vm.previewFile(file) } label: {
                    Label("Preview", systemImage: "eye.fill")
                }
            }
            if vm.canSave(file) {
                Button { vm.saveToDevice(file.path) } label: {
                    Label("Save to Files", systemImage: "arrow.down.to.line.compact")
                }
            }
            if vm.canShare(file) {
                Button { vm.shareFile(file.path) } label: {
                    Label("Share", systemImage: "square.and.arrow.up.fill")
                }
            }
            Button {
                vm.renameTargetPath = file.path
                vm.renameText = (file.name as NSString).deletingPathExtension
                vm.showRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            Button {
                let nsName = file.name as NSString
                let ext = ".\(nsName.pathExtension)"
                let base = nsName.deletingPathExtension
                let dest = URL(fileURLWithPath: file.path)
                    .deletingLastPathComponent()
                    .appendingPathComponent(base + " copy" + ext).path
                vm.copyFile(from: file.path, to: dest)
            } label: {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            Divider()
            Button(role: .destructive) { vm.deleteFile(file.path) } label: {
                Label("Delete", systemImage: "trash.fill")
            }
        }
    }

    @ViewBuilder
    private var emptyOverlay: some View {
        if displayFiles.isEmpty && !vm.isLoading {
            ContentUnavailableView(
                searchText.isEmpty ? "No Items" : "No Results",
                systemImage: searchText.isEmpty ? "folder" : "magnifyingglass"
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { loadData() } label: {
                if vm.isLoading {
                    ProgressView().scaleEffect(0.75)
                } else {
                    Image(systemName: "arrow.clockwise").font(.system(size: 15, weight: .medium))
                }
            }
            .disabled(vm.isLoading)
        }
    }

    @ViewBuilder
    private var pendingOverlay: some View {
        if vm.isPendingSave || vm.isPendingShare || vm.isPendingPreview {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().scaleEffect(1.2).tint(.white)
                Text(pendingOverlayText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                if vm.isPendingPreview {
                    Button {
                        vm.cancelPreview()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var pendingOverlayText: String {
        if vm.isPendingShare { return "Getting file…" }
        if vm.isPendingSave { return "Transferring…" }
        return "Loading preview…"
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )
    }

    private var previewBinding: Binding<QuickLookPreviewItem?> {
        Binding(
            get: { vm.pendingPreviewItem },
            set: { newValue in
                if newValue == nil { vm.consumePreviewItem() }
            }
        )
    }

    private var largeFileAlertBinding: Binding<Bool> {
        Binding(
            get: { vm.largeFileAlert != nil },
            set: { if !$0 { vm.largeFileAlert = nil } }
        )
    }

    @ViewBuilder
    private var largeFileAlertMessage: some View {
        if let info = vm.largeFileAlert {
            let sz = info.fileSize.isEmpty ? "" : " (\(info.fileSize))"
            Text("\(info.fileName)\(sz) is too large to preview on iPhone.\n\nTap \"Open on Mac\" to open it there.")
        } else {
            Text("This file is too large to preview on iPhone.")
        }
    }

    private func loadData() {
        if mode == .recents { vm.loadRecents() } else { vm.load(path: path) }
    }
}

struct FileEmptyView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Select a Location")
                .foregroundStyle(.secondary).font(.system(size: 17))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}
