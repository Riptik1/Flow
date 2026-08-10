//
//  FlowApp.swift
//  Flow
//
//  Created by Riptik Jhajhria on 10/05/26.
//

import SwiftUI

@main
struct FlowApp: App {
    @AppStorage("flow.appearance") private var appearance: String = "system"
    @State private var displayedScheme: ColorScheme?
    @State private var transitionOverlayOpacity: Double = 0

    var body: some Scene {
        WindowGroup {
            DashboardView()
                .preferredColorScheme(displayedScheme)
                .overlay(
                    Color.black
                        .opacity(transitionOverlayOpacity)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                )
                .onAppear {
                    displayedScheme = preferredColorScheme
                }
                .onChange(of: appearance) { _, _ in
                    animateAppearanceChange()
                }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    private func animateAppearanceChange() {
        withAnimation(.easeInOut(duration: 0.18)) {
            transitionOverlayOpacity = 0.35
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            displayedScheme = preferredColorScheme
            withAnimation(.easeInOut(duration: 0.28)) {
                transitionOverlayOpacity = 0
            }
        }
    }
}
