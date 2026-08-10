//
//  TrackpadViewModel.swift
//  Flow
//
//  Created by Riptik Jhajhria on 04/07/26.
//

import SwiftUI
import Combine

final class TrackpadViewModel: ObservableObject {
    @AppStorage("hasSeenTrackpadInstructions") var hasSeenInstructions = false
    @Published var showInstructions = false
    @Published var showBackButton = false
    @Published var isLandscapeLeft = false

    func onAppear() {
        if !hasSeenInstructions {
            showInstructions = true
        } else {
            updateOrientation()
            lockLandscape()
        }
    }

    func onDisappear() {
        unlockOrientation()
    }

    func handleOrientationChange() {
        if !showInstructions { updateOrientation() }
    }

    func dismissInstructions() {
        showInstructions = false
        hasSeenInstructions = true
        updateOrientation()
        lockLandscape()
    }

    func updateOrientation() {
        let o = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.interfaceOrientation ?? .unknown
        if o == .landscapeLeft  { isLandscapeLeft = true }
        if o == .landscapeRight { isLandscapeLeft = false }
    }

    func lockLandscape() {
        AppDelegate.orientationLock = .landscape
        if #available(iOS 16.0, *) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
    }

    func unlockOrientation() {
        AppDelegate.orientationLock = .all
        if #available(iOS 16.0, *) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .all))
            scene.windows.first?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
