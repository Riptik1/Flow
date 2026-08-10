//
//  PreviewShareItems.swift
//  Flow
//
//  Created by Riptik Jhajhria on 03/07/26.
//

import Foundation
import UniformTypeIdentifiers

struct QuickLookPreviewItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let fileName: String
    let kind: FileKind
    let sourcePath: String

    init(data: Data, uti: String, fileName: String = "File", kind: FileKind = .other, sourcePath: String = "") {
        let ext: String
        if let mapped = UTType(uti)?.preferredFilenameExtension, !mapped.isEmpty {
            ext = mapped
        } else {
            let fallback = (fileName as NSString).pathExtension
            ext = fallback.isEmpty ? "bin" : fallback
        }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("flow-preview", isDirectory: true)
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let tempURL = directory.appendingPathComponent(UUID().uuidString + "." + ext)
        try? data.write(to: tempURL)
        self.url = tempURL
        self.fileName = fileName
        self.kind = kind
        self.sourcePath = sourcePath
    }
}

struct ShareItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL

    init(data: Data, uti: String) {
        let ext = UTType(uti)?.preferredFilenameExtension ?? "bin"
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString + "." + ext)
        try? data.write(to: tempURL)
        self.url = tempURL
    }
}
