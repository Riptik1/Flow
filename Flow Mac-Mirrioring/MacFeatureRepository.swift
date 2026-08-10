#if canImport(AppKit)
import Foundation

final class MacFeatureRepository {
    static let shared = MacFeatureRepository()

    private init() {}

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        print("[Flow][MacRepo] handle: message=\(message)")
        AppLaunchService.shared.handle(message, reply: reply)
        ClipboardService.shared.handle(message, reply: reply)
        FileService.shared.handle(message, reply: reply)
        TerminalService.shared.handle(message, reply: reply)
        MacUnlockService.shared.handle(message, reply: reply)
        AppMirroringService.shared.handle(message, reply: reply)
    }
}
#endif