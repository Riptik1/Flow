//
//  FileStore.swift
//  Flow
//
//  Created by Riptik Jhajhria on 17/05/26.
//

import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

final class FileStore: ObservableObject {
    @Published var currentPath: String = "~"
    @Published var isLoading = false
    @Published var permissionGranted = false
    @Published var missingPermissions: [String] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        ConnectionManager.shared.messageStream
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.handle($0) }
            .store(in: &cancellables)
    }

    func checkPermissions() {
        isLoading = true
        ConnectionManager.shared.send(.checkPermissions)
    }

    func loadDirectory(_ path: String) {
        currentPath = path
    }

    func navigateToParent() {
        let parent = URL(fileURLWithPath: currentPath).deletingLastPathComponent().path
        currentPath = parent
    }

    private func handle(_ message: FlowMessage) {
        switch message {
        case .permissionStatus(let granted, let missing):
            isLoading = false
            permissionGranted = granted
            missingPermissions = missing
        default:
            break
        }
    }
}

struct ShareSheetView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct DocumentSavePicker: UIViewControllerRepresentable {
    let url: URL
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let p = UIDocumentPickerViewController(forExporting: [url], asCopy: true)
        p.delegate = context.coordinator
        return p
    }

    func updateUIViewController(_ vc: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(dismiss: dismiss) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let dismiss: DismissAction
        init(dismiss: DismissAction) { self.dismiss = dismiss }
        func documentPickerWasCancelled(_ c: UIDocumentPickerViewController) { dismiss() }
        func documentPicker(_ c: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { dismiss() }
    }
}
