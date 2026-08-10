//
//  KeyboardView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 17/05/26.
//

import SwiftUI

struct MacKeyboardView: View {
    let factory: FlowViewModelFactory
    @StateObject private var vm: KeyboardViewModel
    @ObservedObject private var access = PremiumAccessManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showBack = false
    @State private var showSubscription = false

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makeKeyboardViewModel())
    }

    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        GeometryReader { geo in
            let isPad: Bool = isIPad
            let hEdge: CGFloat = isPad ? 28.0 : 12.0
            let vPad: CGFloat = isPad ? 8.0 : 0.0
            let usableW: CGFloat = isPad ? max(1.0, geo.size.width - hEdge * 2.0) : max(1.0, geo.size.width - hEdge)
            let unitW: CGFloat = max(1.0, (usableW - KeyboardLayout.gap * 18.0) / 15.5)
            let tbH: CGFloat = isPad ? 52.0 : max(28.0, unitW * 0.92)
            let tbGap: CGFloat = isPad ? 13.0 : 8.0
            let usableH: CGFloat = max(1.0, geo.size.height - (vPad * 2.0))
            let keyH: CGFloat = max(10.0, min((usableH - tbH - tbGap - (KeyboardLayout.gap * 4.0)) / 5.0, unitW * 1.25))
            let fs: CGFloat = max(9.0, unitW * 0.28)
            let safeTop: CGFloat = geo.safeAreaInsets.top
            let safeLeft: CGFloat = geo.safeAreaInsets.leading

            ZStack(alignment: .topLeading) {
                VStack(spacing: KeyboardLayout.gap) {
                    Spacer(minLength: 0)
                    CardOverlay(state: access.overlayState, cornerRadius: min(10.0, tbH * 0.36), onAction: { showSubscription = true }) {
                        DynamicTouchBar(
                            tbH: tbH, fnOn: vm.fnOn, isMuted: vm.isMuted,
                            frontApp: vm.frontApp, browserTabs: vm.browserTabs, xcodeFiles: vm.xcodeFiles,
                            showEmoji: $vm.showEmoji,
                            onFnToggle: { vm.fnOn.toggle() },
                            onMuteToggle: { vm.toggleMute() },
                            onSend: { vm.send($0) },
                            onType: { vm.typeString($0) }
                        )
                    }
                    .padding(.bottom, tbGap - KeyboardLayout.gap)

                    KeyboardRow(keys: KeyboardLayout.row1, availW: usableW, keyH: keyH, capsOn: vm.capsOn, fs: fs, activeKeys: vm.activeKeys, onPress: vm.handleKey)
                    KeyboardRow(keys: KeyboardLayout.row2, availW: usableW, keyH: keyH, capsOn: vm.capsOn, fs: fs, activeKeys: vm.activeKeys, onPress: vm.handleKey)
                    KeyboardRow(keys: KeyboardLayout.row3, availW: usableW, keyH: keyH, capsOn: vm.capsOn, fs: fs, activeKeys: vm.activeKeys, onPress: vm.handleKey)
                    KeyboardRow(keys: KeyboardLayout.row4, availW: usableW, keyH: keyH, capsOn: vm.capsOn, fs: fs, activeKeys: vm.activeKeys, onPress: vm.handleKey)
                    BottomKeyRow(
                        availW: usableW, keyH: keyH, capsOn: vm.capsOn, fs: fs,
                        activeKeys: vm.activeKeys, onPress: vm.handleKey,
                        onArrow: { vm.sendArrow($0) }
                    )
                }
                .padding(.horizontal, hEdge)
                .padding(.vertical, vPad)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                ZStack {
                    if showBack {
                        KBBackButton { dismiss() }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.55, anchor: .topLeading).combined(with: .opacity),
                                removal:   .scale(scale: 0.55, anchor: .topLeading).combined(with: .opacity)))
                            .padding(.leading, isPad ? 22.0 : 0.0)
                            .padding(.top, isPad ? -30.0 : 0.0)
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { showBack = true }
                        } label: {
                            KBCornerHintDot(isIPad: isPad)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: showBack)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.top, safeTop + (isPad ? 12.0 : 10.0))
                .padding(.leading, safeLeft + (isPad ? -14.0 : -92.0))
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture {
            if showBack  { withAnimation(.spring(response: 0.28)) { showBack  = false } }
            if vm.showEmoji { withAnimation(.easeOut(duration: 0.12)) { vm.showEmoji = false } }
        }
        .onAppear {
            vm.forceLandscape()
            vm.requestTouchBarState()
        }
        .onDisappear {
            vm.unlockOrientation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            if UIDevice.current.orientation.isPortrait { vm.forceLandscape() }
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack { SubscriptionView(factory: factory) }
        }
    }
}

#Preview { MacKeyboardView() }
