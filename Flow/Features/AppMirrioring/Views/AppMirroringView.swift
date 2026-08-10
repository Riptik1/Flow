//
//  AppMirroringView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//


import SwiftUI

struct AppMirroringView: View {
    let bundleID: String
    let appName: String
    let onClose: () -> Void
    let factory: FlowViewModelFactory

    @StateObject private var viewModel: AppMirroringViewModel
    @State private var zoomScale: CGFloat = 1.0
    @State private var zoomOffset: CGSize = .zero

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 8.0

    init(bundleID: String, appName: String, onClose: @escaping () -> Void,
         factory: FlowViewModelFactory = DefaultFlowViewModelFactory.shared) {
        self.bundleID = bundleID
        self.appName = appName
        self.onClose = onClose
        self.factory = factory
        _viewModel = StateObject(wrappedValue: factory.makeAppMirroringViewModel())
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if let error = viewModel.errorMessage {
                    errorView(error)
                } else {
                    FrameLayerView(renderer: viewModel.renderer)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .scaleEffect(zoomScale, anchor: .topLeading)
                        .offset(zoomOffset)
                        .ignoresSafeArea()
                        .opacity(viewModel.hasReceivedFrame ? 1 : 0)

                    if !viewModel.hasReceivedFrame {
                        loadingView
                    }
                }

                MirrorControlLayer(
                    containerSize: geo.size,
                    captureAspect: viewModel.captureAspect,
                    showKeyboard: viewModel.showKeyboard,
                    onTap: { rawPt in
                        let pt = unzoomedPoint(rawPt)
                        viewModel.sendTap(location: pt, viewSize: geo.size)
                    },
                    onDoubleTap: { rawPt in
                        let pt = unzoomedPoint(rawPt)
                        viewModel.sendDoubleTap(location: pt, viewSize: geo.size)
                    },
                    onRightClick: { rawPt in
                        let pt = unzoomedPoint(rawPt)
                        viewModel.sendRightClick(location: pt, viewSize: geo.size)
                    },
                    onDragBegan: { rawPt in
                        let pt = unzoomedPoint(rawPt)
                        viewModel.sendTouch(phase: 0, location: pt, viewSize: geo.size)
                    },
                    onDragMoved: { rawPt in
                        let pt = unzoomedPoint(rawPt)
                        viewModel.sendTouch(phase: 1, location: pt, viewSize: geo.size)
                    },
                    onDragEnded: { rawPt in
                        let pt = unzoomedPoint(rawPt)
                        viewModel.sendTouch(phase: 2, location: pt, viewSize: geo.size)
                    },
                    onSelectionBegan: { rawPt in
                        let pt = unzoomedPoint(rawPt)
                        viewModel.sendTouch(phase: 0, location: pt, viewSize: geo.size)
                    },
                    onSelectionMoved: { rawPt in
                        let pt = unzoomedPoint(rawPt)
                        viewModel.sendTouch(phase: 1, location: pt, viewSize: geo.size)
                    },
                    onSelectionEnded: { rawPt in
                        let pt = unzoomedPoint(rawPt)
                        viewModel.sendTouch(phase: 2, location: pt, viewSize: geo.size)
                        viewModel.selectionMenuLocation = rawPt
                    },
                    onScroll: { dx, dy in
                        if zoomScale > 1.05 {
                            let raw = CGSize(
                                width: zoomOffset.width + dx,
                                height: zoomOffset.height + dy
                            )
                            zoomOffset = clampedOffset(raw, scale: zoomScale, in: geo.size)
                        } else {
                            viewModel.sendScroll(deltaX: dx, deltaY: dy)
                        }
                    },
                    onPinchChanged: { delta, anchor in
                        let newScale = (zoomScale * delta).clamped(to: minZoom...maxZoom)
                        let effectiveDelta = newScale / zoomScale
                        let p = CGPoint(x: anchor.x * geo.size.width, y: anchor.y * geo.size.height)
                        let newOffset = CGSize(
                            width: p.x * (1 - effectiveDelta) + zoomOffset.width * effectiveDelta,
                            height: p.y * (1 - effectiveDelta) + zoomOffset.height * effectiveDelta
                        )
                        zoomScale = newScale
                        zoomOffset = clampedOffset(newOffset, scale: newScale, in: geo.size)
                    },
                    onPinchEnded: {
                        if zoomScale < 1.1 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                zoomScale = 1.0; zoomOffset = .zero
                            }
                        }
                    },
                    onKey: { code, mods, pressed in
                        viewModel.sendKey(keyCode: Int(code.rawValue), modifiers: mods, pressed: pressed)
                    },
                    onText: { text in
                        viewModel.sendText(text)
                    }
                )
                .frame(width: geo.size.width, height: geo.size.height)

                if let loc = viewModel.selectionMenuLocation {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.selectionMenuLocation = nil }
                        .ignoresSafeArea()

                    SelectionActionMenu(
                        onCopy: { viewModel.copySelection() },
                        onCut: { viewModel.cutSelection() },
                        onShare: { viewModel.shareSelection() }
                    )
                    .position(
                        x: min(max(loc.x, 90), geo.size.width - 90),
                        y: max(loc.y - 46, 40)
                    )
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { viewModel.startMirroring(bundleID: bundleID) }
        .onDisappear { viewModel.stopMirroring() }
        .onChange(of: bundleID) { _, newBundleID in
            zoomScale = 1.0
            zoomOffset = .zero
            viewModel.switchApp(to: newBundleID)
        }
        .sheet(isPresented: Binding(
            get: { viewModel.shareText != nil },
            set: { if !$0 { viewModel.shareText = nil } }
        )) {
            ActivityShareSheet(text: viewModel.shareText ?? "") { viewModel.shareText = nil }
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 8) {
                Button { viewModel.showKeyboard.toggle() } label: {
                    Image(systemName: viewModel.showKeyboard ? "keyboard.fill" : "keyboard")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                if zoomScale > 1.05 {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            zoomScale = 1.0; zoomOffset = .zero
                        }
                    } label: {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .transition(.scale.combined(with: .opacity))
                }
                Button { viewModel.stopMirroring(); onClose() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            .animation(.easeInOut(duration: 0.2), value: zoomScale > 1.05)
            .padding(.top, 12).padding(.trailing, 12)
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 4) {
                Text(appName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial).clipShape(Capsule())
                if zoomScale > 1.05 {
                    Text(String(format: "%.1f×", zoomScale))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Color.black.opacity(0.45)).clipShape(Capsule())
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: zoomScale > 1.05)
            .padding(.top, 16).padding(.leading, 16)
        }
        .statusBar(hidden: true)
    }

    private func unzoomedPoint(_ pt: CGPoint) -> CGPoint {
        CGPoint(
            x: (pt.x - zoomOffset.width) / zoomScale,
            y: (pt.y - zoomOffset.height) / zoomScale
        )
    }

    private func clampedOffset(_ offset: CGSize, scale: CGFloat, in size: CGSize) -> CGSize {
        let minX = size.width  * (1 - scale)
        let minY = size.height * (1 - scale)
        return CGSize(
            width:  offset.width.clamped(to: minX...0),
            height: offset.height.clamped(to: minY...0)
        )
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView().scaleEffect(1.5).tint(.white)
            Text(viewModel.statusText)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center).padding(.horizontal, 32)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundStyle(.orange)
            Text("Connection Failed")
                .font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
            Text(error)
                .font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center).padding(.horizontal, 32)
            Button { viewModel.stopMirroring(); onClose() } label: {
                Text("Close")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .background(Color.white.opacity(0.15)).clipShape(Capsule())
            }
        }
    }
}

private struct SelectionActionMenu: View {
    let onCopy: () -> Void
    let onCut: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            button("Copy", system: "doc.on.doc", action: onCopy)
            divider
            button("Cut", system: "scissors", action: onCut)
            divider
            button("Share", system: "square.and.arrow.up", action: onShare)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 1, height: 24)
    }

    private func button(_ title: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: system).font(.system(size: 15, weight: .medium))
                Text(title).font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.white)
            .frame(width: 64, height: 52)
        }
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let text: String
    let onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in onDismiss() }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
