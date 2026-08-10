import AVFoundation
import CoreBluetooth
import LocalAuthentication
import SwiftUI
import UserNotifications

final class PermissionsViewModel: ObservableObject {
    @Published var cameraAuthorized = false
    @Published var microphoneAuthorized = false
    @Published var notificationsAuthorized = false
    @Published var faceIDAvailable = false
    @Published var bluetoothAuthorized = false
    @Published var localNetworkAuthorized = false
    @Published var showFaceIDAlert = false
    @Published var showLocalNetworkAlert = false

    func checkAllPermissions() {
        checkCamera()
        checkMicrophone()
        checkNotifications()
        checkFaceID()
        checkBluetooth()
        checkLocalNetwork()
    }

    private func checkCamera() {
        cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    private func checkMicrophone() {
        microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func checkNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { [weak self] in
                self?.notificationsAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    private func checkFaceID() {
        let context = LAContext()
        var error: NSError?
        faceIDAvailable = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    private func checkBluetooth() {
        bluetoothAuthorized = CBCentralManager.authorization == .allowedAlways
    }

    private func checkLocalNetwork() {
        localNetworkAuthorized = false
    }

    func handleNotifications(openSettings: @escaping () -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .notDetermined:
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
                        DispatchQueue.main.async { self?.checkNotifications() }
                    }
                default:
                    openSettings()
                }
            }
        }
    }

    func handleCamera(openSettings: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] _ in
                DispatchQueue.main.async { self?.checkCamera() }
            }
        default:
            openSettings()
        }
    }

    func handleMicrophone(openSettings: @escaping () -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] _ in
                DispatchQueue.main.async { self?.checkMicrophone() }
            }
        default:
            openSettings()
        }
    }

    func handleFaceID(openSettings: @escaping () -> Void) {
        let context = LAContext()
        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        if canEvaluate { openSettings() } else { showFaceIDAlert = true }
    }

    func handleBluetooth(openSettings: @escaping () -> Void) {
        switch CBCentralManager.authorization {
        case .notDetermined:
            _ = CBCentralManager()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.checkBluetooth() }
        default:
            openSettings()
        }
    }

    func handleLocalNetwork() {
        showLocalNetworkAlert = true
    }
}
