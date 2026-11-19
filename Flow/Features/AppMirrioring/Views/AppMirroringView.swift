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
    @ObservedObject private var access = PremiumAccessManager.shared
    @State private var zoomScale: CGFloat = 1.0
    @State private var zoomOffset: CGSize = .zero
    @State private var lastOrientationWasLandscape: Bool?
    @State private var lastAppliedCaptureAspect: CGFloat = 0
    @State private var isZoomLocked = false
    @State private var showSubscription = false
    @State private var showPremiumAlert = false
    @State private var showBrightnessMenu = false

    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 8.0

    init(bundleID: String, appName: String, onClose: @escaping () -> Void,
         factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.bundleID = bundleID
        self.appName = appName
        self.onClose = onClose
        self.factory = factory
        _viewModel = StateObject(wrappedValue: factory.makeAppMirroringViewModel())
    }

    var body: some View {
        CardOverlay(state: access.overlayState, cornerRadius: 0, onAction: { showPremiumAlert = true }) {
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
                            if isZoomLocked {
                                viewModel.sendScroll(deltaX: dx, deltaY: dy)
                            } else if zoomScale > 1.05 {
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
                            guard !isZoomLocked else { return }
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
                            guard !isZoomLocked else { return }
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
                    .ignoresSafeArea()

                    if showBrightnessMenu {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { withAnimation(.easeOut(duration: 0.15)) { showBrightnessMenu = false } }
                            .ignoresSafeArea()
                    }

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
                .onChange(of: geo.size) { _, newSize in
                    handleContainerSizeChange(newSize)
                }
                .onChange(of: viewModel.captureAspect) { _, _ in
                    handleContainerSizeChange(geo.size)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            guard access.hasPremiumAccess else { showPremiumAlert = true; return }
            viewModel.startMirroring(bundleID: bundleID)
        }
        .premiumExpiredAlert(isPresented: $showPremiumAlert, feature: "App Mirroring") { showSubscription = true }
        .onDisappear { viewModel.stopMirroring() }
        .onChange(of: bundleID) { _, newBundleID in
            zoomScale = 1.0
            zoomOffset = .zero
            lastOrientationWasLandscape = nil
            lastAppliedCaptureAspect = 0
            isZoomLocked = false
            guard access.hasPremiumAccess else { return }
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
                        if isZoomLocked {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                zoomScale = 1.0; zoomOffset = .zero
                            }
                            isZoomLocked = false
                        } else {
                            isZoomLocked = true
                        }
                    } label: {
                        Image(systemName: isZoomLocked ? "lock.fill" : "lock.open")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(isZoomLocked ? Color.blue.opacity(0.7) : Color.black.opacity(0.5))
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
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Button {
                        withAnimation(.easeOut(duration: 0.15)) { showBrightnessMenu.toggle() }
                        if showBrightnessMenu { viewModel.requestBrightness() }
                    } label: {
                        Image(systemName: viewModel.macBrightness < 0.02 ? "eye.slash.fill" : "eye.slash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(showBrightnessMenu || viewModel.macBrightness < 0.02
                                        ? Color.blue.opacity(0.75) : Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Privacy: Mac screen brightness")

                    Text(appName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial).clipShape(Capsule())
                }
                if showBrightnessMenu {
                    PrivacyBrightnessMenu(
                        level: viewModel.macBrightness,
                        onChange: { viewModel.setBrightness($0) },
                        onCommit: { viewModel.commitBrightness() }
                    )
                    .transition(.scale(scale: 0.92, anchor: .topLeading).combined(with: .opacity))
                }
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
        .sheet(isPresented: $showSubscription) {
            NavigationStack { SubscriptionView(factory: factory) }
        }
    }

    private func handleContainerSizeChange(_ size: CGSize) {
        guard size.width > 0, size.height > 0, !isZoomLocked else { return }
        let isLandscape = size.width > size.height
        let aspectChanged = viewModel.captureAspect != lastAppliedCaptureAspect
        let orientationChanged = isLandscape != lastOrientationWasLandscape
        guard orientationChanged || (isLandscape && aspectChanged) else { return }
        lastOrientationWasLandscape = isLandscape
        lastAppliedCaptureAspect = viewModel.captureAspect

        guard isLandscape, viewModel.captureAspect > 0 else {
            withAnimation(.easeInOut(duration: 0.2)) {
                zoomScale = 1.0
                zoomOffset = .zero
            }
            return
        }

        let scale = coverScale(containerSize: size, captureAspect: viewModel.captureAspect)
            .clamped(to: minZoom...maxZoom)
        withAnimation(.easeInOut(duration: 0.2)) {
            zoomScale = scale
            zoomOffset = clampedOffset(coverOffset(scale: scale, in: size), scale: scale, in: size)
        }
    }

    private func coverScale(containerSize: CGSize, captureAspect: CGFloat) -> CGFloat {
        guard captureAspect > 0 else { return 1.0 }
        let containerAspect = containerSize.width / containerSize.height
        let ratio = containerAspect / captureAspect
        return ratio > 1 ? ratio : 1 / ratio
    }

    private func coverOffset(scale: CGFloat, in size: CGSize) -> CGSize {
        CGSize(width: size.width * (1 - scale) / 2, height: 0)
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

/// Drop-down for the privacy button: a slider plus quick 0–10 steps. 0 turns the Mac's screen
/// fully dark, so nobody next to it can see it is running (the mirror keeps working).
private struct PrivacyBrightnessMenu: View {
    let level: Double
    let onChange: (Double) -> Void
    let onCommit: () -> Void

    private var percent: Int { Int((level * 100).rounded()) }
    private var step: Int { Int((level * 10).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: level < 0.02 ? "eye.slash.fill" : "sun.max.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text("Mac Brightness")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
            }

            Slider(
                value: Binding(get: { level }, set: { onChange($0) }),
                in: 0...1,
                onEditingChanged: { editing in if !editing { onCommit() } }
            )
            .tint(.white)

            HStack(spacing: 4) {
                ForEach(0...10, id: \.self) { n in
                    Button {
                        onChange(Double(n) / 10)
                        onCommit()
                    } label: {
                        Text("\(n)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(step == n ? Color.white : Color.white.opacity(0.14))
                            .foregroundStyle(step == n ? Color.black : Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }

            Text(level < 0.02
                 ? "Screen is off. Nobody nearby can tell your Mac is on."
                 : "0 turns the Mac's screen fully dark.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.65))
        }
        .foregroundStyle(.white)
        .padding(14)
        .frame(width: 340)
        .background(.ultraThinMaterial)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .environment(\.colorScheme, .dark)
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
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
