import Foundation
import UniformTypeIdentifiers

struct QuickLookPreviewItem: Identifiable, Equatable {
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
