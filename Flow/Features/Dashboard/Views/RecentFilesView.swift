//
//  RecentFilesView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 11/05/26.
//

import SwiftUI

struct RecentFilesView: View {
    let factory: FlowViewModelFactory

    @StateObject private var viewModel: RecentFilesViewModel
    @Environment(\.colorScheme) private var scheme
    @State private var showInfoTip = false

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _viewModel = StateObject(wrappedValue: factory.makeRecentFilesViewModel())
    }

    var body: some View {
        GlassCard(cornerRadius: 20, padding: 16) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 6) {
                    Text("Running Apps")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)

                    Button { showInfoTip = true } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showInfoTip) {
                        Text("Click on running apps to use them on your device")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .padding(12)
                            .frame(maxWidth: 220)
                            .presentationCompactAdaptation(.popover)
                    }

                    Spacer()

                    if viewModel.isRefreshing {
                        ProgressView().scaleEffect(0.6)
                    }
                }

                if !viewModel.runningApps.isEmpty {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4),
                        spacing: 18
                    ) {
                        ForEach(viewModel.runningApps) { app in
                            RunningAppTile(app: app, viewModel: viewModel)
                        }
                    }
                } else if viewModel.isRefreshing {
                    HStack { Spacer(); ProgressView(); Spacer() }.padding(.vertical, 20)
                } else {
                    Text("No running apps")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
            }
        }
        .onAppear { viewModel.onAppear() }
        .onChange(of: viewModel.isConnected) { _, connected in
            if connected { viewModel.refresh(force: false) }
        }
        .fullScreenCover(item: $viewModel.mirroringTarget) { app in
            AppMirroringView(
                bundleID: app.bundleID,
                appName: app.name,
                onClose: { viewModel.mirroringTarget = nil }
            )
        }
    }
}

private struct RunningAppTile: View {
    let app: RunningApp
    @ObservedObject var viewModel: RecentFilesViewModel

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var size: CGFloat { isPad ? 76 : 64 }
    private var corner: CGFloat { size * 0.224 }

    var body: some View {
        Button { viewModel.startMirroring(app) } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    RunningAppIcon(app: app, size: size, cornerRadius: corner)
                    if app.isActive {
                        Circle()
                            .fill(Color(red: 0.18, green: 0.86, blue: 0.40))
                            .frame(width: 11, height: 11)
                            .overlay(Circle().stroke(Color(uiColor: .systemBackground), lineWidth: 2))
                            .offset(x: 2, y: -2)
                    }
                }
                Text(app.name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: size + 10)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) { viewModel.quitApp(app, force: false) } label: {
                Label("Quit", systemImage: "xmark.circle.fill")
            }
            Button(role: .destructive) { viewModel.quitApp(app, force: true) } label: {
                Label("Force Quit", systemImage: "xmark.octagon.fill")
            }
        }
    }
}

private struct RunningAppIcon: View {
    let app: RunningApp
    let size: CGFloat
    let cornerRadius: CGFloat
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(scheme == .dark
                      ? Color(red: 0.20, green: 0.20, blue: 0.24)
                      : Color(red: 0.82, green: 0.82, blue: 0.85))

            if let data = app.iconPNG, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().interpolation(.high).scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .transition(.opacity.animation(.easeIn(duration: 0.16)))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(scheme == .dark ? 0.55 : 0.18), radius: 14, x: 0, y: 6)
        .shadow(color: .black.opacity(scheme == .dark ? 0.28 : 0.07), radius: 3,  x: 0, y: 1)
    }
}
