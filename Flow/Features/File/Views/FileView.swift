//
//  FileView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 17/05/26.
//

import SwiftUI

struct FileView: View {
    let factory: FlowViewModelFactory
    @StateObject private var store: FileStore
    @ObservedObject private var access = PremiumAccessManager.shared
    @State private var showPermissions = false
    @State private var showSubscription = false
    @State private var hasInitialized = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(factory: FlowViewModelFactory = ViewModelFactory.shared) {
        self.factory = factory
        _store = StateObject(wrappedValue: factory.makeFileStore())
    }

    var body: some View {
        CardOverlay(state: access.overlayState, cornerRadius: 0, onAction: { showSubscription = true }) {
            Group {
                if sizeClass == .regular { iPadLayout }
                else { iPhoneLayout }
            }
        }
        .sheet(isPresented: $showPermissions) {
            FilePermissionView(store: store)
        }
        .sheet(isPresented: $showSubscription) {
            NavigationStack { SubscriptionView(factory: factory) }
        }
        .onAppear {
            guard !hasInitialized else { return }
            hasInitialized = true
            guard access.hasPremiumAccess else { return }
            store.checkPermissions()
        }
        .onChange(of: store.permissionGranted) { _, granted in
            if granted {
                showPermissions = false
            } else if hasInitialized && store.missingPermissions.count > 0 {
                showPermissions = true
            }
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            FileSidebarView(store: store, factory: factory, isCompact: false)
        } detail: {
            FileListView(
                title: store.currentPath == "~" ? "Home" : URL(fileURLWithPath: store.currentPath).lastPathComponent,
                path: store.currentPath,
                store: store,
                mode: .directory,
                factory: factory
            )
        }
    }

    private var iPhoneLayout: some View {
        NavigationStack {
            FileSidebarView(store: store, factory: factory, isCompact: true)
        }
    }
}

#Preview {
    FileView()
}
