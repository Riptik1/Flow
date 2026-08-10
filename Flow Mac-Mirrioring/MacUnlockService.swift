import Foundation
import AppKit
import LocalAuthentication

final class MacUnlockService {
    static let shared = MacUnlockService()

    private init() {}

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        guard case .unlockMac(let password) = message else { return }

        unlockScreen(with: password) { success in
            if success {
                reply(.unlockSuccess)
            } else {
                reply(.unlockFailed)
            }
        }
    }

    func checkLockState() -> Bool {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any]
        let isLocked = session?["OnConsole"] as? Bool == false
        return isLocked
    }

    func sendLockStateUpdate(via connection: ConnectionManager) {
        let isLocked = checkLockState()
        connection.send(.macLockedState(locked: isLocked))
    }

    private func unlockScreen(with password: String, completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: Unmanaged<CFError>?

        guard let passwordData = password.data(using: .utf8) else {
            completion(false)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "flow_unlock",
            kSecValueData as String: passwordData,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true
        ]

        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: """
                tell application "System Events"
                    keystroke "\(password)"
                    delay 0.1
                    keystroke return
                end tell
            """)

            var scriptError: NSDictionary?
            script?.executeAndReturnError(&scriptError)

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let isStillLocked = self.checkLockState()
                completion(!isStillLocked)
            }
        }
    }

    func startLockStateMonitoring(via connection: ConnectionManager) {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            self.sendLockStateUpdate(via: connection)
        }
    }
}