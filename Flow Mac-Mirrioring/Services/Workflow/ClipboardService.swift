//
//  ClipboardService.swift
//  Flow
//
//  Created by Riptik Jhajhria on 31/05/26.
//

#if canImport(AppKit)
import AppKit
import CoreGraphics

final class ClipboardService {
    static let shared = ClipboardService()

    private var history: [ClipboardItem] = []
    private var lastChangeCount: Int = -1
    private var suppressNextChange = false
    private var pollTimer: Timer?
    private let maxHistory = 50
    private let src: CGEventSource? = CGEventSource(stateID: .hidSystemState)

    private var storageURL: URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("Flow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("clipboard_history.json")
    }

    private init() {
        DispatchQueue.main.async {
            self.loadPersistedHistory()
            self.bootstrapCurrentClipboard()
            let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
                self?.checkClipboard()
            }
            timer.tolerance = 0.1
            RunLoop.main.add(timer, forMode: .common)
            self.pollTimer = timer
        }
    }

    private func loadPersistedHistory() {
        guard let data = try? Data(contentsOf: storageURL),
              let decoded = try? JSONDecoder().decode([ClipboardItem].self, from: data) else { return }
        history = decoded
    }

    private func saveHistory() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self else { return }
            guard let data = try? JSONEncoder().encode(self.history) else { return }
            try? data.write(to: self.storageURL, options: .atomic)
        }
    }

    private func bootstrapCurrentClipboard() {
        let pb = NSPasteboard.general
        lastChangeCount = pb.changeCount

        if pb.canReadObject(forClasses: [NSImage.self], options: nil),
           let image = NSImage(pasteboard: pb) {
            if let data = compressImage(image) {
                let item = ClipboardItem(
                    id: UUID(), contentType: .image,
                    text: nil, imageData: data,
                    timestamp: Date().timeIntervalSince1970
                )
                push(item, notify: false)
            }
        } else if let str = pb.string(forType: .string), !str.isEmpty {
            let item = ClipboardItem(
                id: UUID(), contentType: detectType(str),
                text: String(str.prefix(3000)), imageData: nil,
                timestamp: Date().timeIntervalSince1970
            )
            push(item, notify: false)
        }
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if suppressNextChange {
            suppressNextChange = false
            return
        }

        if pb.canReadObject(forClasses: [NSImage.self], options: nil),
           let image = NSImage(pasteboard: pb) {
            let snapshot = image
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self else { return }
                guard let data = self.compressImage(snapshot) else { return }
                let item = ClipboardItem(
                    id: UUID(), contentType: .image,
                    text: nil, imageData: data,
                    timestamp: Date().timeIntervalSince1970
                )
                DispatchQueue.main.async {
                    self.push(item, notify: true)
                }
            }
            return
        }

        if let str = pb.string(forType: .string), !str.isEmpty {
            let item = ClipboardItem(
                id: UUID(), contentType: detectType(str),
                text: String(str.prefix(3000)), imageData: nil,
                timestamp: Date().timeIntervalSince1970
            )
            push(item, notify: true)
        }
    }

    private func push(_ item: ClipboardItem, notify: Bool) {
        if let text = item.text {
            history.removeAll { $0.text == text }
        }
        history.insert(item, at: 0)
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }
        saveHistory()
        if notify {
            ConnectionManager.shared.send(.clipboardDidChange(item: item))
        }
    }

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .requestClipboardHistory:
            DispatchQueue.main.async {
                let pb = NSPasteboard.general
                let current = pb.changeCount
                if current != self.lastChangeCount {
                    self.lastChangeCount = current
                    if let str = pb.string(forType: .string), !str.isEmpty {
                        let item = ClipboardItem(
                            id: UUID(), contentType: self.detectType(str),
                            text: String(str.prefix(3000)), imageData: nil,
                            timestamp: Date().timeIntervalSince1970
                        )
                        self.push(item, notify: false)
                    }
                }
                reply(.clipboardHistory(items: self.history))
            }
        case .pasteClipboardItem(let id):
            pasteItem(withID: id)
        default:
            break
        }
    }

    private func pasteItem(withID id: UUID) {
        DispatchQueue.main.async {
            guard let item = self.history.first(where: { $0.id == id }) else { return }
            let pb = NSPasteboard.general
            self.suppressNextChange = true
            pb.clearContents()
            if let text = item.text {
                pb.setString(text, forType: .string)
            } else if let data = item.imageData, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
            self.lastChangeCount = pb.changeCount
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                let down = CGEvent(keyboardEventSource: self.src, virtualKey: 9, keyDown: true)
                down?.flags = .maskCommand
                down?.post(tap: .cghidEventTap)
                let up = CGEvent(keyboardEventSource: self.src, virtualKey: 9, keyDown: false)
                up?.flags = .maskCommand
                up?.post(tap: .cghidEventTap)
            }
        }
    }

    private func compressImage(_ image: NSImage) -> Data? {
        let maxDim: CGFloat = 280
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(maxDim / size.width, maxDim / size.height, 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: CGRect(origin: .zero, size: newSize),
                   from: CGRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        newImage.unlockFocus()
        guard let tiff = newImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: 0.60)])
    }

    private func detectType(_ string: String) -> ClipboardContentType {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }
        if !trimmed.contains("\n"),
           trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("ftp://") {
            return .url
        }
        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            if (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) != nil { return .json }
        }
        let upper = trimmed.uppercased()
        let sqlStarters = ["SELECT ", "INSERT INTO", "UPDATE ", "DELETE FROM",
                           "CREATE TABLE", "DROP TABLE", "ALTER TABLE", "CREATE INDEX", "WITH "]
        if sqlStarters.contains(where: { upper.hasPrefix($0) }) { return .sql }
        if trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ") ||
           trimmed.hasPrefix("### ") || trimmed.hasPrefix("#### ") { return .markdown }
        if trimmed.contains("\n") &&
           (trimmed.contains("**") || trimmed.contains("```") ||
            trimmed.components(separatedBy: "\n").filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") }.count >= 2) {
            return .markdown
        }
        let codeKeywords = ["func ", "class ", "struct ", "enum ", "import ",
                            "const ", "let ", "var ", "def ", "return ", "function ",
                            "async ", "await ", "fn ", "pub fn", "#include", "package ",
                            "using namespace", "interface ", "void ", "int ", "String "]
        let codeSymbols  = ["() {", "() =>", "-> {", ") {", "){", "};",
                            "===", "!==", "=>", "&&", "||", "++", "--", "::"]
        let kwHits  = codeKeywords.filter { trimmed.contains($0) }.count
        let symHits = codeSymbols.filter  { trimmed.contains($0) }.count
        if (kwHits >= 1 && trimmed.contains("{")) || symHits >= 2 { return .code }
        return .text
    }
}
#endif
