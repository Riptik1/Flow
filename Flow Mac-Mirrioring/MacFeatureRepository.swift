//
//  MacFeatureRepository.swift
//  Flow
//
//  Created by Riptik Jhajhria on 16/07/26.
//


#if canImport(AppKit)
import Foundation

final class MacFeatureRepository {
    static let shared = MacFeatureRepository()

    private init() {}

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        flowLog("[Flow][MacRepo] handle: message=\(message.logLabel)")
        guard MacPermissionManager.shared.allows(message, reply: reply) else { return }
        AppLaunchService.shared.handle(message, reply: reply)
        ClipboardService.shared.handle(message, reply: reply)
        FileService.shared.handle(message, reply: reply)
        TerminalService.shared.handle(message, reply: reply)
        MacUnlockService.shared.handle(message, reply: reply)
        RemoteAppMirroringHost.shared.handle(message, reply: reply)
    }
}
#endif
