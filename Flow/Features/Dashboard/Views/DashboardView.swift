//
//  DashboardView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 10/05/26.
//

import SwiftUI
import Combine

struct DashboardView: View {
    let factory: FlowViewModelFactory
    // @StateObject private var connection = ConnectionManager.shared
    @StateObject private var connection = FlowConnectionRepository.shared
    @StateObject private var vm: DashboardViewModel
    @StateObject private var spotlightVM: SpotlightViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var scheme

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    @State private var showSidebar   = false
    @State private var dragOffset: CGFloat = 0
    @State private var showLaunchApp = false
    @State private var showWorkflows = false
    @State private var showTerminal  = false
    @State private var showClipboard = false
    @State private var showSpotlight = false
    @State private var showSettings = false
    @State private var showPermissions = false
    @State private var showSubscription = false
    @State private var showDevices = false
    @State private var showRemotePairing = false
    @FocusState private var spotlightFocused: Bool

    @AppStorage("flow.didFinishSetup") private var didFinishSetup = false
    @AppStorage("flow.remotePromptSnoozeUntil") private var remotePromptSnoozeUntil: Double = 0
    @ObservedObject private var localNetwork = LocalNetworkPermission.shared
    @ObservedObject private var deviceRepo = DeviceRepository.shared
    @State private var showRemotePrompt = false
    @State private var remotePromptShownThisSession = false
    @State private var showLocalNetworkDenied = false
    @State private var localDeniedShownThisSession = false

    private let sidebarWidth: CGFloat = 270
    private let sidebarAnimation: Animation = .spring(response: 0.22, dampingFraction: 0.92)

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makeDashboardViewModel())
        _spotlightVM = StateObject(wrappedValue: factory.makeSpotlightViewModel())
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                Color(uiColor: .systemBackground).ignoresSafeArea()

                if isPad {
                    iPadLayout
                } else {
                    iPhoneLayout
                        .animation(nil, value: showSidebar)
                        .animation(nil, value: dragOffset)
                    sidebarOverlayLayer
                }

                if showSpotlight {
                    SpotlightOverlay(
                        vm: spotlightVM,
                        spotlightFocused: $spotlightFocused,
                        onDismiss: { withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) { showSpotlight = false } },
                        onOpen: { result in
                            spotlightVM.openResult(result)
                            withAnimation(.spring(response: 0.26, dampingFraction: 0.84)) { showSpotlight = false }
                        }
                    )
                }

                if vm.isMacLocked && connection.state == .connected {
                    MacUnlockOverlay(factory: factory)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        .zIndex(100)
                }

                if let toast = vm.toast {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ActionToast(message: toast.message, icon: toast.icon, color: toast.color)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            Spacer()
                        }
                        .padding(.bottom, isPad ? 40 : 32)
                    }
                    .frame(maxWidth: .infinity)
                    .ignoresSafeArea(edges: .bottom)
                    .allowsHitTesting(false)
                    .zIndex(200)
                }
            }
            .gesture(
                !isPad ? DragGesture(minimumDistance: 15)
                    .onChanged { value in
                        let t = value.translation.width
                        if showSidebar { if t < 0 { dragOffset = t } }
                        else { if value.startLocation.x < 45 && t > 0 { dragOffset = t } }
                    }
                    .onEnded { value in
                        let t = value.translation.width
                        let v = value.predictedEndLocation.x - value.location.x
                        withAnimation(sidebarAnimation) {
                            if showSidebar { if t < -60 || v < -200 { showSidebar = false } }
                            else           { if t >  60 || v >  200 { showSidebar = true  } }
                            dragOffset = 0
                        }
                    } : nil
            )
            .navigationDestination(isPresented: $showLaunchApp)  { LaunchAppView(mode: .launch, factory: factory) }
            .navigationDestination(isPresented: $showWorkflows)   { WorkflowsView(factory: factory) }
            .navigationDestination(isPresented: $showTerminal)    { TerminalView(factory: factory) }
            .navigationDestination(isPresented: $showClipboard)   { ClipboardView(factory: factory) }
            .navigationDestination(isPresented: $showSettings) { SettingsView() }
            .navigationDestination(isPresented: $showPermissions) { PermissionsView(factory: factory) }
            .navigationDestination(isPresented: $showSubscription) { SubscriptionView(factory: factory) }
            .navigationDestination(isPresented: $showDevices) { DevicesView(factory: factory) }
        }
        .sheet(isPresented: $showRemotePairing) { RemotePairingView() }
        .fullScreenCover(isPresented: Binding(get: { !didFinishSetup }, set: { _ in })) {
            FirstLaunchSetupView { didFinishSetup = true }
        }
        .alert("Use your Mac from anywhere?", isPresented: $showRemotePrompt) {
            Button("Enter Code") { showRemotePairing = true }
            Button("Not Now", role: .cancel) {
                // Don't nag: ask again in 3 days.
                remotePromptSnoozeUntil = Date().addingTimeInterval(3 * 24 * 3600).timeIntervalSince1970
            }
        } message: {
            Text("You're connected on Wi-Fi. To also connect from anywhere:\n\n1. On your Mac, click “Generate Pairing Code”.\n2. Tap “Enter Code” and type it.")
        }
        .alert("Local Network is off", isPresented: $showLocalNetworkDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("Flow needs it to find your Mac on Wi-Fi. Turn it on in Settings.")
        }
        .onAppear {
            print("DashboardView[lifecycle]: onAppear")
            vm.start()
        }
        .onChange(of: scenePhase) { _, phase in
            print("DashboardView[lifecycle]: scenePhase -> \(phase)")
            if phase == .active {
                vm.handleForeground()
            }
        }
        .onReceive(BackTapCoordinator.shared.$lastTriggeredWorkflow.compactMap { $0 }) { wf in
            vm.fireToast(ToastPresentation(message: "▶ \(wf.name)", icon: wf.iconName, color: Color(hex: wf.iconColorHex)))
        }
        .onChange(of: showSpotlight) { _, visible in
            if visible {
                spotlightVM.reset()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { spotlightFocused = true }
            } else {
                spotlightFocused = false
            }
        }
        .onChange(of: connection.state) { _, newState in
            print("DashboardView[lifecycle]: observed connection.state -> \(newState)")
            if newState == .connected, connection.connectedPeer?.transport == .local {
                scheduleRemotePrompt()
            }
        }
        .onChange(of: localNetwork.status) { _, status in
            if status == .denied, didFinishSetup, !localDeniedShownThisSession {
                localDeniedShownThisSession = true
                showLocalNetworkDenied = true
            }
        }
    }

    /// After a Wi-Fi connection, offer to also set up remote access (once per launch,
    /// and never when a remote Mac is already paired).
    private func scheduleRemotePrompt() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            guard didFinishSetup,
                  !remotePromptShownThisSession,
                  !showRemotePairing,
                  connection.state == .connected,
                  connection.connectedPeer?.transport == .local,
                  Date().timeIntervalSince1970 > remotePromptSnoozeUntil,
                  DeviceRepository.shared.currentDevices.isEmpty
            else { return }
            remotePromptShownThisSession = true
            showRemotePrompt = true
        }
    }

    private func handleSidebarSelection(_ item: String) {
        switch item {
        case "Permissions": showPermissions = true
        case "Subscription": showSubscription = true
        case "Devices": showDevices = true
        default: break
        }
        if !isPad {
            withAnimation(sidebarAnimation) { showSidebar = false }
        }
    }

    private func quickActionsView(style: QuickActionsView.Style) -> some View {
        QuickActionsView(
            style: style,
            isMuted:     vm.isMuted,
            onLaunchApp: { showLaunchApp = true },
            onWorkflows: { showWorkflows = true },
            onTerminal:  { showTerminal  = true },
            onClipboard: { showClipboard = true },
            onSearch:    { withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) { showSpotlight = true } },
            onMute:      { vm.toggleMute() },
            onLock:      { vm.lockMac() },
            onShutDown:  { vm.shutDownMac() },
            onFireToast: { vm.fireToast($0) }
        )
    }

    private var customTopBar: some View {
        HStack {
            Button { withAnimation(sidebarAnimation) { showSidebar = true } } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.gray)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(scheme == .dark ? 0.07 : 0.04))
                    .clipShape(Circle())
            }
            Spacer()
            Text("FLOW")
                .font(.system(size: 21, weight: .black, design: .rounded))
                .tracking(4)
                .foregroundStyle(
                    LinearGradient(colors: [.primary, .primary.opacity(0.75)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Spacer()
            Button { showSettings = true } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.gray)
                    .frame(width: 44, height: 44)
                    .background(Color.primary.opacity(scheme == .dark ? 0.07 : 0.04))
                    .clipShape(Circle())
            }
        }
        .padding(.vertical, 8)
    }

    private var isRemoteConfiguredForConnectedMac: Bool {
        guard let peer = connection.connectedPeer else { return false }
        return peer.transport == .remote || deviceRepo.devices.contains { $0.name == peer.deviceName }
    }

    private var connectionKindLabel: String {
        connection.connectedPeer?.transport == .remote ? "Remote" : "Same Wi‑Fi"
    }

    @ViewBuilder
    private var connectionStatusBanner: some View {
        switch connection.state {
        case .disconnected, .searching:
            Button(action: { showRemotePairing = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "personalhotspot")
                        .font(.system(size: 13, weight: .medium))
                    Text("Connect to your Mac remotely")
                        .font(.system(size: 13, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

        case .connecting:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Connecting to your Mac…")
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
            .foregroundStyle(.blue)

        case .connected where isRemoteConfiguredForConnectedMac:
            // Already set up for remote access – nothing to offer, the device card says how we're connected.
            EmptyView()

        case .connected:
            Button(action: { showRemotePairing = true }) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .shadow(color: .green.opacity(0.7), radius: 3)
                    Text("Connected to \(connection.connectedPeer?.deviceName ?? "your Mac")")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    Text(connectionKindLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
    }

    private var iPhoneLayout: some View {
        VStack(spacing: 0) {
            // Fixed header: stays in place while the cards scroll underneath.
            customTopBar
                .padding(.horizontal, 16)
                .padding(.top, -8)
                .background(Color(uiColor: .systemBackground))
                .zIndex(1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    connectionStatusBanner

                DeviceInfoCard()
                TrackpadCard()
                HStack(alignment: .top, spacing: 14) { KeyboardCard(); FilesCard() }.frame(height: 170)
                quickActionsView(style: .grid)
                RecentFilesView(factory: factory)
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 24)
            }
        }
    }

    private var iPadLayout: some View {
        HStack(spacing: 0) {
            SidebarView(onSelect: handleSidebarSelection)
            Divider()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    connectionStatusBanner
                    DeviceInfoCard()
                    HStack(alignment: .top, spacing: 20) {
                        TrackpadCard()
                        VStack(spacing: 20) { KeyboardCard(); FilesCard() }.frame(width: 290)
                    }
                    quickActionsView(style: .row)
                    RecentFilesView(factory: factory)
                }
                .padding(24)
            }
        }
    }

    @ViewBuilder
    private var sidebarOverlayLayer: some View {
        let offset             = showSidebar ? dragOffset : -sidebarWidth + dragOffset
        let clampedOffset      = min(0, max(-sidebarWidth, offset))
        let visibilityFraction = (sidebarWidth + clampedOffset) / sidebarWidth

        ZStack(alignment: .leading) {
            Color.black
                .opacity(0.35 * visibilityFraction)
                .ignoresSafeArea()
                .allowsHitTesting(visibilityFraction > 0.01)
                .onTapGesture { withAnimation(sidebarAnimation) { showSidebar = false } }
            SidebarView(onSelect: handleSidebarSelection)
                .frame(width: sidebarWidth)
                .offset(x: clampedOffset)
                .ignoresSafeArea(edges: .bottom)
        }
        .ignoresSafeArea()
    }
}

#Preview { DashboardView() }
