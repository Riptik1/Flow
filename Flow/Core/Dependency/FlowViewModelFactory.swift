//
//  FlowViewModelFactory.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import Foundation

protocol FlowViewModelFactory {
    func makeFileStore() -> FileStore
    func makeFileListViewModel() -> FileListViewModel
    func makeKeyboardViewModel() -> KeyboardViewModel
    func makeTrackpadViewModel() -> TrackpadViewModel

    func makeDashboardViewModel() -> DashboardViewModel
    func makeSpotlightViewModel() -> SpotlightViewModel
    func makePermissionsViewModel() -> PermissionsViewModel
    func makeDevicesViewModel() -> DevicesViewModel
    func makeSubscriptionViewModel() -> SubscriptionViewModel
    func makeSuggestImprovementsViewModel() -> SuggestImprovementsViewModel
    func makeLaunchAppViewModel() -> LaunchAppViewModel
    func makeAppIconLoaderViewModel() -> AppIconLoaderViewModel
    func makeClipboardViewModel() -> ClipboardViewModel
    func makeRecentFilesViewModel() -> RecentFilesViewModel
    func makeAppMirroringViewModel() -> AppMirroringViewModel
    func makeTerminalStore() -> TerminalStore
    func makeWorkflowsViewModel() -> WorkflowsViewModel
    func makeWorkflowNamingViewModel(existingWorkflow: AppWorkflow?, selectedBundleIDs: [String]) -> WorkflowNamingViewModel
    func makeMacUnlockViewModel() -> MacUnlockViewModel
}

final class ViewModelFactory: FlowViewModelFactory {
    static let shared = ViewModelFactory()

    private let connectionService: FlowConnectionServicing

    private let appRepository: AppRepositoryProtocol
    private let clipboardRepository: ClipboardRepositoryProtocol
    private let recentFilesRepository: RecentFilesRepositoryProtocol
    private let workflowRepository: WorkflowRepositoryProtocol
    private let deviceRepository: DeviceRepositoryProtocol

    init(connectionService: FlowConnectionServicing = FlowConnectionRepository.shared,
         appRepository: AppRepositoryProtocol = AppRepository.shared,
         clipboardRepository: ClipboardRepositoryProtocol = ClipboardRepository.shared,
         recentFilesRepository: RecentFilesRepositoryProtocol = RecentFilesRepository.shared,
         workflowRepository: WorkflowRepositoryProtocol = WorkflowRepository.shared,
         deviceRepository: DeviceRepositoryProtocol = DeviceRepository.shared) {
        self.connectionService = connectionService
        self.appRepository = appRepository
        self.clipboardRepository = clipboardRepository
        self.recentFilesRepository = recentFilesRepository
        self.workflowRepository = workflowRepository
        self.deviceRepository = deviceRepository
    }

    func makeFileStore() -> FileStore {
        FileStore(connectionService: connectionService)
    }

    func makeFileListViewModel() -> FileListViewModel {
        FileListViewModel(connectionService: connectionService)
    }

    func makeKeyboardViewModel() -> KeyboardViewModel {
        KeyboardViewModel(connectionService: connectionService)
    }

    func makeTrackpadViewModel() -> TrackpadViewModel {
        TrackpadViewModel()
    }

    func makeDashboardViewModel() -> DashboardViewModel {
        DashboardViewModel(connectionService: connectionService)
    }

    func makeSpotlightViewModel() -> SpotlightViewModel {
        SpotlightViewModel(connectionService: connectionService)
    }

    func makePermissionsViewModel() -> PermissionsViewModel {
        PermissionsViewModel()
    }

    func makeDevicesViewModel() -> DevicesViewModel {
        DevicesViewModel(repository: deviceRepository)
    }

    func makeSubscriptionViewModel() -> SubscriptionViewModel {
        SubscriptionViewModel()
    }

    func makeSuggestImprovementsViewModel() -> SuggestImprovementsViewModel {
        SuggestImprovementsViewModel()
    }

    func makeLaunchAppViewModel() -> LaunchAppViewModel {
        LaunchAppViewModel(repository: appRepository, connectionService: connectionService)
    }

    func makeAppIconLoaderViewModel() -> AppIconLoaderViewModel {
        AppIconLoaderViewModel(repository: appRepository)
    }

    func makeClipboardViewModel() -> ClipboardViewModel {
        ClipboardViewModel(repository: clipboardRepository, connectionService: connectionService)
    }

    func makeRecentFilesViewModel() -> RecentFilesViewModel {
        RecentFilesViewModel(connectionService: connectionService)
    }

    func makeAppMirroringViewModel() -> AppMirroringViewModel {
        AppMirroringViewModel(connectionService: connectionService)
    }

    func makeTerminalStore() -> TerminalStore {
        TerminalStore.shared
    }

    func makeWorkflowsViewModel() -> WorkflowsViewModel {
        WorkflowsViewModel(repository: workflowRepository, connectionService: connectionService)
    }

    func makeWorkflowNamingViewModel(existingWorkflow: AppWorkflow?, selectedBundleIDs: [String]) -> WorkflowNamingViewModel {
        WorkflowNamingViewModel(existingWorkflow: existingWorkflow, selectedBundleIDs: selectedBundleIDs)
    }

    func makeMacUnlockViewModel() -> MacUnlockViewModel {
        MacUnlockViewModel(connectionService: connectionService)
    }
}
