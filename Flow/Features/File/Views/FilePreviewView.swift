//
//  FilePreviewView.swift
//  Flow
//
//  Created by Riptik Jhajhria on 24/05/26.
//


//
//  FilePreviewView.swift
//  Flow
//
//  Created by Assistant on 24/05/26.
//

import SwiftUI
import QuickLook

struct FilePreviewView: View {
    let item: QuickLookPreviewItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            QuickLookPreview(item: item)
                .ignoresSafeArea()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct QuickLookPreview: UIViewControllerRepresentable {
    let item: QuickLookPreviewItem

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(item: item)
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource {
        let item: QuickLookPreviewItem

        init(item: QuickLookPreviewItem) {
            self.item = item
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            item.url as QLPreviewItem
        }
    }
}