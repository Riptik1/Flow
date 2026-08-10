//
//  LaunchAppViewMode.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import SwiftUI

enum LaunchAppViewMode {
    case launch
    case workflowPicker(preselected: Set<String>, onDone: (Set<String>) -> Void)
    var isWorkflowPicker: Bool {
        if case .workflowPicker = self { return true }
        return false
    }
}

struct LaunchAppView: View {
    var mode: LaunchAppViewMode = .launch
    let factory: FlowViewModelFactory

    @StateObject private var viewModel: LaunchAppViewModel
    @Environment(\.colorScheme) private var scheme
    @FocusState private var searchFocused: Bool
    @State private var selectedIDs: Set<String> = []

    init(mode: LaunchAppViewMode = .launch, factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.mode = mode
        self.factory = factory
        _viewModel = StateObject(wrappedValue: factory.makeLaunchAppViewModel())
    }

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var columns: Int { isPad ? 5 : 3 }
    private var iconSize: CGFloat { isPad ? 110 : 88 }

    private var navTitle: String {
        switch mode { case .launch: return "Launch App"; case .workflowPicker: return "Select Apps" }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                if viewModel.showSearch {
                    searchBarView.transition(.move(edge: .top).combined(with: .opacity))
                }
                contentArea
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.85), value: viewModel.showSearch)
            if case .workflowPicker(_, let onDone) = mode { doneButton(onDone: onDone) }
        }
        .navigationTitle(navTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.showSearch.toggle()
                    if viewModel.showSearch {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { searchFocused = true }
                    } else { searchFocused = false }
                } label: {
                    Image(systemName: viewModel.showSearch ? "xmark.circle.fill" : "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(viewModel.showSearch ? Color.secondary : Color.primary)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
        }
        .onAppear {
            viewModel.onAppear()
            if case .workflowPicker(let pre, _) = mode { selectedIDs = pre }
        }
    }

    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
            TextField("Search apps", text: $viewModel.searchText)
                .font(.system(size: 16))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($searchFocused)
                .submitLabel(.search)
            if !viewModel.searchText.isEmpty {
                Button { viewModel.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 16)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Color.primary.opacity(scheme == .dark ? 0.10 : 0.07)))
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)
    }

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading && viewModel.apps.isEmpty { loadingView }
        else if let error = viewModel.error, viewModel.apps.isEmpty { errorView(message: error) }
        else { appGrid }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            Spacer()
            ProgressView().scaleEffect(1.4).tint(.primary)
            Text("Loading apps from your Mac…").font(.system(size: 15)).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48, weight: .light)).foregroundStyle(.orange)
            VStack(spacing: 6) {
                Text("Couldn't Load Apps").font(.system(size: 17, weight: .semibold))
                Text(message).font(.system(size: 14)).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).padding(.horizontal, 40)
            }
            Button { viewModel.fetchApps() } label: {
                Text("Try Again").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 32).padding(.vertical, 12).background(Capsule().fill(Color.blue))
            }
            .shadow(color: .blue.opacity(0.35), radius: 10, x: 0, y: 5)
            Spacer()
        }
    }

    private var appGrid: some View {
        let bottomPad: CGFloat = mode.isWorkflowPicker ? 110 : 48
        return ScrollView(showsIndicators: false) {
            let displayed = viewModel.filteredApps
            if displayed.isEmpty && !viewModel.searchText.isEmpty {
                VStack(spacing: 14) {
                    Spacer(minLength: 80)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40, weight: .light)).foregroundStyle(.quaternary)
                    Text("No results for \"\(viewModel.searchText)\"")
                        .font(.system(size: 15)).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: isPad ? 6 : 4), count: columns),
                    spacing: isPad ? 36 : 28
                ) {
                    ForEach(displayed) { app in
                        AppCell(
                            app: app,
                            iconSize: iconSize,
                            isPad: isPad,
                            isSelected: mode.isWorkflowPicker ? selectedIDs.contains(app.bundleID) : nil,
                            factory: factory
                        ) { handleCellTap(app: app) }
                    }
                }
                .padding(.horizontal, isPad ? 20 : 12)
                .padding(.top, 28)
                .padding(.bottom, bottomPad)
            }
        }
    }

    private func doneButton(onDone: @escaping (Set<String>) -> Void) -> some View {
        VStack {
            Spacer()
            Button {
                guard !selectedIDs.isEmpty else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onDone(selectedIDs)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 17, weight: .semibold))
                    Text(selectedIDs.isEmpty
                         ? "Select Apps to Continue"
                         : "Done — \(selectedIDs.count) App\(selectedIDs.count == 1 ? "" : "s")")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(selectedIDs.isEmpty
                              ? LinearGradient(colors: [.secondary.opacity(0.35), .secondary.opacity(0.35)], startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [Color(hex: "10B981"), Color(hex: "059669")], startPoint: .topLeading, endPoint: .bottomTrailing))
                )
                .shadow(color: selectedIDs.isEmpty ? .clear : Color(hex: "10B981").opacity(0.4), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(selectedIDs.isEmpty)
            .animation(.easeInOut(duration: 0.2), value: selectedIDs.isEmpty)
            .padding(.horizontal, isPad ? 40 : 20)
            .padding(.bottom, 28)
        }
    }

    private func handleCellTap(app: MacApp) {
        switch mode {
        case .launch: viewModel.launch(app)
        case .workflowPicker:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if selectedIDs.contains(app.bundleID) { selectedIDs.remove(app.bundleID) }
            else { selectedIDs.insert(app.bundleID) }
        }
    }
}

private struct AppCell: View {
    let app: MacApp
    let iconSize: CGFloat
    let isPad: Bool
    let isSelected: Bool?
    let factory: FlowViewModelFactory
    let onTap: () -> Void

    private var labelSize: CGFloat { isPad ? 13 : 12 }
    private var cr: CGFloat { iconSize * 0.2237 }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: isPad ? 11 : 9) {
                ZStack(alignment: .topTrailing) {
                    CachedAppIconView(
                        bundleID: app.bundleID,
                        size: iconSize,
                        cornerRadius: cr,
                        isSelected: isSelected,
                        factory: factory
                    )
                    if isSelected == true {
                        ZStack {
                            Circle().fill(Color(hex: "10B981")).frame(width: 24, height: 24)
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                        }
                        .offset(x: 6, y: -6)
                    }
                }
                Text(app.name)
                    .font(.system(size: labelSize, weight: .medium)).foregroundStyle(.primary)
                    .lineLimit(2).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: labelSize * 2.9).frame(maxWidth: iconSize + 10)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppCellButtonStyle())
    }
}

private struct AppCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.84 : 1.0)
            .opacity(configuration.isPressed ? 0.70 : 1.0)
            .animation(.spring(response: 0.20, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview("Launch Mode") {
    NavigationStack { LaunchAppView(mode: .launch) }
}
#Preview("Workflow Picker") {
    NavigationStack { LaunchAppView(mode: .workflowPicker(preselected: [], onDone: { _ in })) }
}
