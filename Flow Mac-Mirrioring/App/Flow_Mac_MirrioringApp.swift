//
//  Flow_Mac_MirrioringApp.swift
//  Flow Mac-Mirrioring
//
//  Created by Riptik Jhajhria on 24/05/26.
//

import SwiftUI
import AppKit
import ServiceManagement
import Darwin

var FlowShouldAutoSearch = true

@main
struct Flow_Mac_MirrioringApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        MenuBarExtra("Flow", systemImage: "iphone") {
            FlowMenuBarView()
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow?

    func applicationWillFinishLaunching(_ notification: Notification) {
        if isAutoLaunch() {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? SMAppService.mainApp.register()
        if FlowShouldAutoSearch {
            ConnectionManager.shared.startAutoConnect()
        }
        if !isAutoLaunch() {
            showMainWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func showMainWindow() {
        if mainWindow == nil {
            let hostingController = NSHostingController(rootView: FlowMacView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "Flow"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.minSize = NSSize(width: 620, height: 540)
            window.setFrameAutosaveName("FlowMainWindow")
            window.delegate = self
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hideMainWindow() {
        mainWindow?.orderOut(nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            self.hideMainWindow()
        }
    }
}

func isAutoLaunch() -> Bool {
    getppid() == 1
}
