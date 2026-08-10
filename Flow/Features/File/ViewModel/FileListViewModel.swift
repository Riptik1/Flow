//
//  FileListViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import Combine
import Foundation
import UniformTypeIdentifiers

final class FileListViewModel: ObservableObject {
    private static let shareLimit: Int64 = 150 * 1024 * 1024

    @Published var files: [FileItem] = []
    @Published var isLoading = false
    @Published var isPendingPreview = false
    @Published var isPendingSave = false
    @Published var isPendingShare = false
    @Published var errorMessage: String? = nil
    @Published var showRenameAlert = false
    @Published var renameText = ""
    @Published var largeFileAlert: LargeFileAlertInfo? = nil
    @Published private(set) var pendingPreviewItem: QuickLookPreviewItem? = nil
    @Published private(set) var pendingPreviewPath: String? = nil
    @Published private(set) var pendingShareItem: ShareItem? = nil
    @Published private(set) var pendingSaveItem: ShareItem? = nil

    var renameTargetPath: String? = nil
    var reloadPath: String? = nil
    private(set) var pendingResponse: ResponseType = .none
    private var isOperationPending = false
    private var pendingPreviewSource: FileItem? = nil
    private var previewRequestToken: UUID? = nil
    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()

    enum ResponseType { case none, directory, recents, preview, share, saveToDevice }

    init(connectionService: FlowConnectionServicing = LiveFlowConnectionService.shared) {
        self.connectionService = connectionService
        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handle($0) }
            .store(in: &cancellables)
    }

    func load(path: String) {
        isLoading = true
        reloadPath = path
        pendingResponse = .directory
        connectionService.send(.listDirectory(path: path))
    }

    func loadRecents() {
        isLoading = true
        pendingResponse = .recents
        connectionService.send(.getRecents)
    }

    func previewFile(_ file: FileItem) {
        guard pendingResponse == .none else { return }
        isPendingPreview = true
        pendingResponse = .preview
        pendingPreviewSource = file
        pendingPreviewPath = file.path
        let token = UUID()
        previewRequestToken = token
        connectionService.send(.previewFile(path: file.path))
        schedulePreviewTimeout(token: token)
    }

    func cancelPreview() {
        guard pendingResponse == .preview else { return }
        isPendingPreview = false
        pendingResponse = .none
        pendingPreviewSource = nil
        pendingPreviewPath = nil
        previewRequestToken = nil
    }

    private func schedulePreviewTimeout(token: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            guard let self else { return }
            guard self.previewRequestToken == token, self.pendingResponse == .preview else { return }
            self.isPendingPreview = false
            self.pendingResponse = .none
            self.pendingPreviewSource = nil
            self.pendingPreviewPath = nil
            self.previewRequestToken = nil
            self.errorMessage = "This file is taking too long to load. Please try again."
        }
    }

    func shareFile(_ path: String) {
        guard pendingResponse == .none else { return }
        isPendingShare = true
        pendingResponse = .share
        connectionService.send(.shareFile(path: path))
    }

    func saveToDevice(_ path: String) {
        guard pendingResponse == .none else { return }
        isPendingSave = true
        pendingResponse = .saveToDevice
        connectionService.send(.saveFileToDevice(path: path))
    }

    func openOnMac(_ path: String) {
        connectionService.send(.spotlightOpen(path: path))
    }

    func deleteFile(_ path: String) {
        isOperationPending = true
        connectionService.send(.deleteItem(path: path))
    }

    func copyFile(from: String, to: String) {
        isOperationPending = true
        connectionService.send(.copyItem(from: from, to: to))
    }

    func renameFile(at path: String, newName: String) {
        let dest = URL(fileURLWithPath: path)
            .deletingLastPathComponent()
            .appendingPathComponent(newName).path
        isOperationPending = true
        connectionService.send(.moveItem(from: path, to: dest))
    }

    func consumePreviewItem() { pendingPreviewItem = nil }
    func consumeShareItem() { pendingShareItem = nil }
    func consumeSaveItem() { pendingSaveItem = nil }

    func canShare(_ file: FileItem) -> Bool {
        guard file.kind != .folder, let size = file.rawSize, size > 0 else { return false }
        return size <= Self.shareLimit
    }

    func canSave(_ file: FileItem) -> Bool {
        if file.kind == .folder { return true }
        guard let size = file.rawSize else { return true }
        return size <= (2 * 1024 * 1024 * 1024)
    }

    private func handle(_ message: FlowMessage) {
        switch message {
        case .directoryContents(let r):
            guard pendingResponse == .directory else { return }
            isLoading = false
            pendingResponse = .none
            files = r.map(mapToFileItem)
        case .recentFiles(let r):
            guard pendingResponse == .recents else { return }
            isLoading = false
            pendingResponse = .none
            files = r.map(mapToFileItem)
        case .filePreview(let data, let uti):
            guard pendingResponse == .preview else { return }
            isPendingPreview = false
            pendingResponse = .none
            let source = pendingPreviewSource
            pendingPreviewSource = nil
            pendingPreviewPath = nil
            previewRequestToken = nil
            pendingPreviewItem = QuickLookPreviewItem(
                data: data,
                uti: uti,
                fileName: source?.name ?? "File",
                kind: source?.kind ?? .other,
                sourcePath: source?.path ?? ""
            )
        case .shareData(let data, let uti):
            guard pendingResponse == .share else { return }
            isPendingShare = false
            pendingResponse = .none
            pendingShareItem = ShareItem(data: data, uti: uti)
        case .saveFileData(let data, let uti):
            guard pendingResponse == .saveToDevice else { return }
            isPendingSave = false
            pendingResponse = .none
            pendingSaveItem = ShareItem(data: data, uti: uti)
        case .operationSuccess:
            guard isOperationPending else { return }
            isOperationPending = false
            if let path = reloadPath { load(path: path) }
        case .operationFailure(let error):
            isLoading = false
            isPendingPreview = false
            isPendingSave = false
            isPendingShare = false
            isOperationPending = false
            pendingPreviewSource = nil
            pendingPreviewPath = nil
            previewRequestToken = nil
            let wasPreview = pendingResponse == .preview
            pendingResponse = .none
            if wasPreview && error.hasPrefix("FILE_TOO_LARGE_PREVIEW:") {
                let rest = String(error.dropFirst("FILE_TOO_LARGE_PREVIEW:".count))
                let parts = rest.components(separatedBy: ":")
                let fileName = parts.count > 0 ? parts[0] : "This file"
                let fileSize = parts.count > 1 ? parts[1] : ""
                let filePath = parts.count > 2 ? parts[2...].joined(separator: ":") : ""
                largeFileAlert = LargeFileAlertInfo(fileName: fileName, fileSize: fileSize, filePath: filePath)
            } else {
                errorMessage = error
            }
        default:
            break
        }
    }

    private func mapToFileItem(_ r: RemoteFileItem) -> FileItem {
        let date = Date(timeIntervalSince1970: r.dateModified)
        let size: Int64? = (r.size ?? 0) > 0 ? r.size! : nil
        let kind: FileKind = r.isDirectory ? .folder : kindForUTI(r.uti)
        return FileItem(name: r.name, path: r.path, dateModified: date, size: size, kind: kind)
    }

    private func kindForUTI(_ uti: String) -> FileKind {
        guard let t = UTType(uti) else { return .other }
        if t.conforms(to: .image)                                  { return .image }
        if t.conforms(to: .audiovisualContent)                     { return .video }
        if t.conforms(to: .audio)                                  { return .audio }
        if t.conforms(to: .pdf)                                    { return .pdf }
        if t.conforms(to: .archive)                                { return .archive }
        if t.conforms(to: .sourceCode) || t.conforms(to: .script)  { return .code }
        if t.conforms(to: .spreadsheet)                            { return .spreadsheet }
        if t.conforms(to: .text)                                   { return .document }
        return .other
    }
}
