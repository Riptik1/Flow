import Combine
import Foundation
import UIKit
import UniformTypeIdentifiers

final class RecentFilesViewModel: ObservableObject {
    @Published var runningApps: [RunningApp] = []
    @Published var recentFiles: [RemoteFileItem] = []
    @Published var recentProjects: [RecentProject] = []
    @Published var previewItem: QuickLookPreviewItem? = nil
    @Published var shareURL: URL? = nil
    @Published var showPreview = false
    @Published var showShareSheet = false
    @Published var showSaveSuccess = false
    @Published var isRefreshing = false
    @Published var isConnected = false
    @Published var searchQuery = ""
    @Published var showSearchBar = false
    @Published var mirroringTarget: RunningApp? = nil

    var filteredApps: [RunningApp] {
        searchQuery.isEmpty ? runningApps
            : runningApps.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }
    var filesOnly: [RemoteFileItem] { recentFiles.filter { !$0.isDirectory } }
    var filteredFilesOnly: [RemoteFileItem] {
        searchQuery.isEmpty ? filesOnly
            : filesOnly.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }

    enum PendingAction {
        case preview(fileName: String), share(fileName: String)
        case copyImage, saveToPhotos, saveToFiles(fileName: String)
    }

    private let repository: RecentFilesRepositoryProtocol
    private let connectionService: FlowConnectionServicing
    private var cancellables = Set<AnyCancellable>()
    private var pendingAction: PendingAction? = nil
    private var appsReceived = false
    private var filesReceived = false
    private var lastRefreshDate: Date? = nil
    private let minRefreshInterval: TimeInterval = 45

    init(repository: RecentFilesRepositoryProtocol = RecentFilesRepository.shared,
         connectionService: FlowConnectionServicing = LiveFlowConnectionService.shared) {
        self.repository = repository
        self.connectionService = connectionService
        recentFiles = repository.currentFiles

        repository.filesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.recentFiles = $0 }
            .store(in: &cancellables)

        connectionService.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handleMessage($0) }
            .store(in: &cancellables)

        connectionService.isConnectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isConnected = $0 }
            .store(in: &cancellables)
    }

    func onAppear(style: RecentFilesStyle) {
        let shouldFetch: Bool
        if let last = lastRefreshDate {
            shouldFetch = Date().timeIntervalSince(last) > minRefreshInterval
        } else {
            shouldFetch = true
        }
        if shouldFetch { refresh(style: style, force: false) }
    }

    func refresh(style: RecentFilesStyle, force: Bool) {
        guard connectionService.isConnected else { return }
        if !force, let last = lastRefreshDate,
           Date().timeIntervalSince(last) < minRefreshInterval { return }
        isRefreshing = true
        appsReceived = false
        filesReceived = false
        lastRefreshDate = Date()
        let limit = style == .dashboard ? 10 : 30
        connectionService.send(.requestRunningApps)
        repository.refresh(limit: limit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in self?.isRefreshing = false }
    }

    func startMirroring(_ app: RunningApp) {
        mirroringTarget = app
    }

    func openOnMac(_ file: RemoteFileItem)  { connectionService.send(.spotlightOpen(path: file.path)) }
    func activateApp(_ app: RunningApp)     { connectionService.send(.activateApp(bundleID: app.bundleID)) }
    func quitApp(_ app: RunningApp, force: Bool) { connectionService.send(.quitApp(bundleID: app.bundleID, force: force)) }
    func loadRecentProjects(for app: RunningApp) { connectionService.send(.requestAppRecentProjects(bundleID: app.bundleID)) }
    func openProject(_ project: RecentProject)   { connectionService.send(.openProject(path: project.path)) }

    func previewFile(_ file: RemoteFileItem) {
        pendingAction = .preview(fileName: file.name)
        connectionService.send(.previewFile(path: file.path))
    }
    func shareFile(_ file: RemoteFileItem) {
        pendingAction = .share(fileName: file.name)
        connectionService.send(.shareFile(path: file.path))
    }
    func copyImage(_ file: RemoteFileItem) {
        pendingAction = .copyImage
        connectionService.send(.shareFile(path: file.path))
    }
    func saveToPhotos(_ file: RemoteFileItem) {
        pendingAction = .saveToPhotos
        connectionService.send(.shareFile(path: file.path))
    }
    func saveToFiles(_ file: RemoteFileItem) {
        pendingAction = .saveToFiles(fileName: file.name)
        connectionService.send(.shareFile(path: file.path))
    }

    private func handleMessage(_ message: FlowMessage) {
        switch message {
        case .runningApps(let apps):
            runningApps = apps
            appsReceived = true
            if filesReceived { isRefreshing = false }

        case .recentFiles:
            filesReceived = true
            if appsReceived { isRefreshing = false }

        case .filePreview(let d, let u):    processData(d, uti: u)
        case .shareData(let d, let u):      processData(d, uti: u)
        case .appRecentProjects(_, let p):  recentProjects = p
        case .appQuitSuccess:               connectionService.send(.requestRunningApps)
        case .operationFailure:             isRefreshing = false
        default: break
        }
    }

    private func processData(_ data: Data, uti: String) {
        let ext = UTType(uti)?.preferredFilenameExtension ?? "dat"
        let baseName: String
        switch pendingAction {
        case .preview(let n), .share(let n), .saveToFiles(let n): baseName = n
        case .copyImage, .saveToPhotos: baseName = "image"
        case .none: baseName = "file"
        }
        let name = (baseName as NSString).deletingPathExtension + "." + ext
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? data.write(to: tempURL)
        switch pendingAction {
        case .preview:
            previewItem = QuickLookPreviewItem(data: data, uti: uti); showPreview = true
        case .share:
            shareURL = tempURL; showShareSheet = true
        case .copyImage:
            if let img = UIImage(data: data) { UIPasteboard.general.image = img }
        case .saveToPhotos:
            if let img = UIImage(data: data) { UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil); showSaveSuccess = true }
        case .saveToFiles:
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            try? data.write(to: docs.appendingPathComponent(name)); showSaveSuccess = true
        case .none:
            previewItem = QuickLookPreviewItem(data: data, uti: uti); showPreview = true
        }
        pendingAction = nil
    }
}
