//
//  TrackpadView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 18/05/26.
//

import SwiftUI

struct TrackpadView: View {
    let factory: FlowViewModelFactory
    @StateObject private var vm: TrackpadViewModel
    @Environment(\.dismiss) private var dismiss

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _vm = StateObject(wrappedValue: factory.makeTrackpadViewModel())
    }

    private var isIPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }
    private var cornerAlign: Alignment { vm.isLandscapeLeft ? .topTrailing : .topLeading }
    private var scaleAnchor: UnitPoint  { vm.isLandscapeLeft ? .topTrailing : .topLeading }
    private var padEdge: Edge.Set       { vm.isLandscapeLeft ? .trailing    : .leading    }

    var body: some View {
        GeometryReader { geo in
            let safe: CGFloat = vm.isLandscapeLeft ? geo.safeAreaInsets.trailing : geo.safeAreaInsets.leading
            let pad:  CGFloat = isIPad ? 18 : 12
            ZStack {
                TrackpadArea(onTap: {
                    if vm.showBackButton {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) { vm.showBackButton = false }
                    }
                })
                .ignoresSafeArea()
                ZStack {
                    if vm.showBackButton {
                        TrackpadBackButton { dismiss() }
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.55, anchor: scaleAnchor).combined(with: .opacity),
                                removal:   .scale(scale: 0.55, anchor: scaleAnchor).combined(with: .opacity)))
                    } else {
                        Button {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) { vm.showBackButton = true }
                        } label: { TrackpadCornerHintDot(isIPad: isIPad) }
                        .buttonStyle(.plain)
                        .transition(.opacity)
                    }
                }
                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: vm.showBackButton)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: cornerAlign)
                .padding(.top, geo.safeAreaInsets.top + pad)
                .padding(padEdge, safe + pad)
            }
        }
        .ignoresSafeArea()
        .onAppear { vm.onAppear() }
        .onDisappear { vm.onDisappear() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            vm.handleOrientationChange()
        }
        .overlay {
            if vm.showInstructions {
                InstructionOverlay {
                    withAnimation(.easeOut(duration: 0.3)) { vm.dismissInstructions() }
                }
                .transition(.opacity)
                .animation(.easeOut(duration: 0.3), value: vm.showInstructions)
            }
        }
    }
}

#Preview { TrackpadView() }
