//
//  FileItem.swift
//  Flow
//
//  Created by Riptik Jhajhria on 03/07/26.
//

import Foundation

struct FileItem: Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let dateModified: Date
    let rawSize: Int64?
    let kind: FileKind

    init(name: String, path: String, dateModified: Date, size: Int64? = nil, kind: FileKind = .folder) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.dateModified = dateModified
        self.rawSize = size
        self.kind = kind
    }

    var sizeDisplay: String {
        guard let bytes = rawSize, bytes > 0 else { return "--" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    var size: String? {
        guard let bytes = rawSize, bytes > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func == (lhs: FileItem, rhs: FileItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
