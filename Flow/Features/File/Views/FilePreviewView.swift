import SwiftUI
import PDFKit

struct FilePreviewView: View {
    let item: QuickLookPreviewItem
    var onOpenOnMac: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var content: PreviewContent = .loading

    enum PreviewContent {
        case loading
        case image(UIImage)
        case text(String, isCode: Bool)
        case pdf(URL)
        case unsupported(String)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            contentView
                .transition(.opacity)
                .id(contentKey)
        }
        .animation(.easeOut(duration: 0.25), value: contentKey)
        .safeAreaInset(edge: .top) { topBar }
        .onAppear { loadContent() }
    }

    private var contentKey: Int {
        switch content {
        case .loading: return 0
        case .image: return 1
        case .text: return 2
        case .pdf: return 3
        case .unsupported: return 4
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(LinearGradient(colors: [item.kind.tileTopColor, item.kind.tileBottomColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 32, height: 32)
                Image(systemName: item.kind.tileIconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(item.fileName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var contentView: some View {
        switch content {
        case .loading:
            loadingView
        case .image(let img):
            ImageZoomView(image: img)
                .ignoresSafeArea()
        case .text(let str, let isCode):
            textView(str, isCode: isCode)
        case .pdf(let url):
            PDFViewer(url: url)
                .ignoresSafeArea()
        case .unsupported(let ext):
            unsupportedView(ext)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [item.kind.tileTopColor, item.kind.tileBottomColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 76, height: 76)
                    .shadow(color: item.kind.tileTopColor.opacity(0.35), radius: 14, x: 0, y: 6)
                Image(systemName: item.kind.tileIconName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            ProgressView()
                .tint(.white)
            Text(item.fileName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.6))
                .lineLimit(1)
                .truncationMode(.middle)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func textView(_ str: String, isCode: Bool) -> some View {
        ScrollView {
            Text(str)
                .font(isCode ? .system(.caption, design: .monospaced) : .system(.body))
                .foregroundStyle(Color(white: 0.88))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.07, green: 0.07, blue: 0.08))
    }

    private func unsupportedView(_ ext: String) -> some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: [item.kind.tileTopColor, item.kind.tileBottomColor], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 76, height: 76)
                Image(systemName: item.kind.tileIconName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 6) {
                Text(item.fileName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 32)
                Text(ext.isEmpty ? "This file can't be previewed on iPhone" : "\(ext.uppercased()) files can't be previewed on iPhone")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(white: 0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            if let onOpenOnMac {
                Button {
                    onOpenOnMac()
                    dismiss()
                } label: {
                    Label("Open on Mac", systemImage: "arrow.up.right.square")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.blue))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private func loadContent() {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = item.url
            let ext = url.pathExtension.lowercased()
            let imageExts: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "tiff", "tif", "bmp", "ico", "svg"]
            let textExts:  Set<String> = ["txt", "md", "markdown", "json", "xml", "html", "htm", "css", "csv", "log", "yaml", "yml", "toml", "ini", "cfg", "env", "rtf", "plist"]
            let codeExts:  Set<String> = ["swift", "py", "js", "ts", "jsx", "tsx", "java", "c", "cpp", "cc", "h", "hpp", "go", "rs", "rb", "php", "sh", "bash", "zsh", "sql", "kt", "kts", "m", "cs", "scala", "dart", "lua", "r", "pl", "vim", "gradle", "podspec", "lock"]

            let result: PreviewContent
            if ext == "pdf" {
                result = .pdf(url)
            } else if imageExts.contains(ext) {
                if let img = UIImage(contentsOfFile: url.path) {
                    result = .image(img)
                } else {
                    result = .unsupported(ext)
                }
            } else if textExts.contains(ext) || codeExts.contains(ext) {
                if let str = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1)) {
                    result = .text(str, isCode: codeExts.contains(ext))
                } else {
                    result = .unsupported(ext)
                }
            } else {
                result = .unsupported(ext)
            }
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.25)) {
                    self.content = result
                }
            }
        }
    }
}
