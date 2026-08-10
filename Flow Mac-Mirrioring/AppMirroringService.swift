import ScreenCaptureKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import AppKit

private let imageContext = CIContext(options: nil)

@MainActor
final class AppMirroringService: NSObject, SCStreamOutput, SCStreamDelegate {
    static let shared = AppMirroringService()

    private var stream: SCStream?
    private var isRunning = false
    private var targetWindowFrame: CGRect = .zero

    func handle(_ message: FlowMessage, reply: @escaping (FlowMessage) -> Void) {
        switch message {
        case .startAppMirroring(let bundleID):
            startMirroring(bundleID: bundleID, reply: reply)
        case .stopAppMirroring:
            stopMirroring()
        case .appMirroringInputTouch(let phase, let x, let y):
            AppMirroringInputInjector.shared.injectTouch(phase: phase, x: x, y: y, windowFrame: targetWindowFrame)
        case .appMirroringInputScroll(let dx, let dy):
            AppMirroringInputInjector.shared.injectScroll(deltaX: dx, deltaY: dy)
        case .appMirroringInputKey(let keyCode, let modifiers, let pressed):
            AppMirroringInputInjector.shared.injectKey(keyCode: keyCode, modifiers: modifiers, pressed: pressed)
        default:
            break
        }
    }

    private func startMirroring(bundleID: String, reply: @escaping (FlowMessage) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
                guard let window = content.windows.first(where: { $0.owningApplication?.bundleIdentifier == bundleID }) else {
                    reply(.appMirroringError(error: "App window not found"))
                    return
                }

                targetWindowFrame = window.frame

                let running = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == bundleID }
                if !running {
                    AppLaunchService.shared.launch(bundleID: bundleID)
                    try await Task.sleep(nanoseconds: 2_500_000_000)
                }

                let filter = SCContentFilter(desktopIndependentWindow: window)
                let config = SCStreamConfiguration()
                config.width = 1920
                config.height = 1080
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                config.queueDepth = 5

                stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "capture"))

                guard let port = AppMirroringVideoServer.shared.start() else {
                    reply(.appMirroringError(error: "Failed to start video server"))
                    return
                }

                try await stream?.startCapture()
                isRunning = true
                reply(.appMirroringConfig(width: 1920, height: 1080, frameRate: 30, port: port))
                reply(.appMirroringStarted)
            } catch {
                reply(.appMirroringError(error: error.localizedDescription))
            }
        }
    }

    private func stopMirroring() {
        Task {
            await stream?.stopCapture()
            stream = nil
            AppMirroringVideoServer.shared.stop()
            isRunning = false
            targetWindowFrame = .zero
        }
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let imageBuffer = sampleBuffer.imageBuffer else { return }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = imageContext.createCGImage(ciImage, from: ciImage.extent) else { return }

        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.jpeg.identifier as CFString, 1, nil) else { return }
        let properties = [kCGImageDestinationLossyCompressionQuality: 0.65] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        guard CGImageDestinationFinalize(destination) else { return }

        let data = mutableData as Data
        Task { @MainActor in
            AppMirroringVideoServer.shared.sendFrame(data)
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        Task { @MainActor in
            AppMirroringVideoServer.shared.stop()
            self.isRunning = false
        }
    }
}