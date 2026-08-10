#if canImport(AppKit)
import AppKit
import CoreGraphics

final class ClipboardService {
    static let shared = ClipboardService()

    private var history: [ClipboardItem] = []
    private var lastChangeCount: Int = -1
    private var pollTimer: Timer?
    private let queue = DispatchQueue(label: "com.flow.clipboard", qos: .userInitiated)
    private let maxHistory = 25
    private let src: CGEventSource? = CGEventSource(stateID: .hidSystemState)

    private init() {
        DispatchQueue.main.async { self.startPolling() }
    }

    private func startPolling() {
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        pollTimer?.tolerance = 0.1
        RunLoop.main.add(pollTimer!, forMode: .common)
    }

    private func checkClipboard() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        queue.async { [weak self] in
            guard let self else { return }
            guard let item = self.captureCurrentClipboard() else { return }
            DispatchQueue.main.async {
                if let text = item.text {
                    self.history.removeAll { $0.text == text && $0.imageData == nil }
                } else if item.imageData != nil {
                    self.history.removeAll { $0.imageData != nil && $0.text == nil }
                }
                self.history.insert(item, at: 0)
                if self.history.count > self.maxHistory {
                    self.history = Array(self.history.prefix(self.maxHistory))
                }
                ConnectionManager.shared.send(.clipboardDidChange(item: item))
            }
        }
    }

    private func captureCurrentClipboard() -> ClipboardItem? {
        let pb = NSPasteboard.general

        if pb.canReadObject(forClasses: [NSImage.self], options: nil),
           let image = NSImage(pasteboard: pb) {
            let compressed = compressImage(image)
            return ClipboardItem(
                id: UUID(),
                contentType: .image,
                text: nil,
                imageData: compressed,
                timestamp: Date().timeIntervalSince1970
            )
        }

        if let str = pb.string(forType: .string), !str.isEmpty {
            let type = detectType(str)
            let truncated = String(str.prefix(3000))
            return ClipboardItem(
                id: UUID(),
                contentType: type,
                text: truncated,
                imageData: nil,
                timestamp: Date().timeIntervalSince1970
            )
        }

        return nil
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
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: NSNumber(value: 0.55)])
    }

    private func detectType(_ string: String) -> ClipboardContentType {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .text }

        if !trimmed.contains("\n"),
           trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") || trimmed.hasPrefix("ftp://") {
            return .url
        }

        if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
            if let _ = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) {
                return .json
            }
        }

        let upper = trimmed.uppercased()
        let sqlStarters = ["SELECT ", "INSERT INTO", "UPDATE ", "DELETE FROM", "CREATE TABLE",
                           "DROP TABLE", "ALTER TABLE", "CREATE INDEX", "WITH "]
        if sqlStarters.contains(where: { upper.hasPrefix($0) }) {
            return .sql
        }

        if trimmed.hasPrefix("# ") || trimmed.hasPrefix("## ") || trimmed.hasPrefix("### ") ||
           trimmed.hasPrefix("#### ") {
            return .markdown
        }
        if trimmed.contains("\n") &&
           (trimmed.contains("**") || trimmed.contains("```") ||
            (trimmed.components(separatedBy: "\n").filter { $0.hasPrefix("- ") || $0.hasPrefix("* ") }.count >= 2)) {
            return .markdown
        }

        let codeKeywords = ["func ", "class ", "struct ", "enum ", "import ",
                            "const ", "let ", "var ", "def ", "return ", "function ",
                            "async ", "await ", "fn ", "pub fn", "#include", "package ",
                            "using namespace", "interface ", "void ", "int ", "String "]
        let codeSymbols  = ["() {", "() =>", "-> {", ") {", "){", "};", "};",
                            "===", "!==", "=>", "&&", "||", "++", "--", "::"]

        let kwHits  = codeKeywords.filter { trimmed.contains($0) }.count
        let symHits = codeSymbols.filter  { trimmed.contains($0) }.count

        if (kwHits >= 1 && trimmed.contains("{")) || symHits >= 2 {
            return .code
        }

        return .text
    }

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .requestClipboardHistory:
            DispatchQueue.main.async {
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
            pb.clearContents()
            if let text = item.text {
                pb.setString(text, forType: .string)
            } else if let data = item.imageData, let image = NSImage(data: data) {
                pb.writeObjects([image])
            }
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
}
#endif