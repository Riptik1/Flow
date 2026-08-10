//
//  FrameRenderer.swift
//  Flow
//
//  Created by Riptik Jhajhria on 06/07/26.
//

import AVFoundation
import CoreMedia
import SwiftUI

final class FrameRenderer {
    private let decodeQueue = DispatchQueue(label: "flow.decode", qos: .userInteractive)
    private weak var displayLayer: AVSampleBufferDisplayLayer?
    private var formatDescription: CMVideoFormatDescription?
    private var spsData: Data?
    private var ppsData: Data?

    init() {}

    func attach(to layer: AVSampleBufferDisplayLayer) {
        displayLayer = layer
    }

    func display(_ data: Data) {
        decodeQueue.async { [weak self] in
            self?.process(data)
        }
    }

    private func process(_ data: Data) {
        for nal in Self.splitNALUnits(data) {
            guard let first = nal.first else { continue }
            switch first & 0x1F {
            case 7:
                spsData = nal
                rebuildFormatDescriptionIfNeeded()
            case 8:
                ppsData = nal
                rebuildFormatDescriptionIfNeeded()
            case 1, 5:
                enqueue(nal: nal)
            default:
                break
            }
        }
    }

    private func rebuildFormatDescriptionIfNeeded() {
        guard let spsData, let ppsData else { return }
        spsData.withUnsafeBytes { spsRaw in
            ppsData.withUnsafeBytes { ppsRaw in
                guard let spsBase = spsRaw.bindMemory(to: UInt8.self).baseAddress,
                      let ppsBase = ppsRaw.bindMemory(to: UInt8.self).baseAddress else { return }
                let pointers: [UnsafePointer<UInt8>] = [spsBase, ppsBase]
                let sizes: [Int] = [spsData.count, ppsData.count]
                var desc: CMFormatDescription?
                let status = pointers.withUnsafeBufferPointer { pointerBuf in
                    sizes.withUnsafeBufferPointer { sizeBuf in
                        CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: 2,
                            parameterSetPointers: pointerBuf.baseAddress!,
                            parameterSetSizes: sizeBuf.baseAddress!,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &desc
                        )
                    }
                }
                if status == noErr {
                    formatDescription = desc
                }
            }
        }
    }

    private func enqueue(nal: Data) {
        guard let formatDescription, let displayLayer else { return }

        var avcc = Data(count: 4 + nal.count)
        avcc.withUnsafeMutableBytes { raw in
            var length = UInt32(nal.count).bigEndian
            withUnsafeBytes(of: &length) { raw.baseAddress!.copyMemory(from: $0.baseAddress!, byteCount: 4) }
        }
        avcc.replaceSubrange(4..<avcc.count, with: nal)

        var blockBuffer: CMBlockBuffer?
        let createStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: avcc.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: avcc.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard createStatus == noErr, let blockBuffer else { return }

        let copyStatus = avcc.withUnsafeBytes { raw -> OSStatus in
            CMBlockBufferReplaceDataBytes(with: raw.baseAddress!, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: avcc.count)
        }
        guard copyStatus == noErr else { return }

        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()), decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        var sampleSize = avcc.count
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr, let sampleBuffer else { return }

        if let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: true) {
            let dict = unsafeBitCast(CFArrayGetValueAtIndex(attachmentsArray, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(
                dict,
                Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
                Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
            )
        }

        DispatchQueue.main.async {
            if displayLayer.status == .failed {
                displayLayer.flush()
            }
            displayLayer.enqueue(sampleBuffer)
        }
    }

    private static func splitNALUnits(_ data: Data) -> [Data] {
        let bytes = [UInt8](data)
        var markers: [(start: Int, codeLength: Int)] = []
        var i = 0
        while i + 2 < bytes.count {
            if bytes[i] == 0, bytes[i + 1] == 0, bytes[i + 2] == 1 {
                markers.append((i + 3, 3))
                i += 3
            } else if i + 3 < bytes.count, bytes[i] == 0, bytes[i + 1] == 0, bytes[i + 2] == 0, bytes[i + 3] == 1 {
                markers.append((i + 4, 4))
                i += 4
            } else {
                i += 1
            }
        }
        var result: [Data] = []
        for (idx, marker) in markers.enumerated() {
            let end = idx + 1 < markers.count ? markers[idx + 1].start - markers[idx + 1].codeLength : bytes.count
            if end > marker.start {
                result.append(Data(bytes[marker.start..<end]))
            }
        }
        return result
    }
}

struct FrameLayerView: UIViewRepresentable {
    let renderer: FrameRenderer

    func makeUIView(context: Context) -> FrameBackingView {
        let v = FrameBackingView()
        v.backgroundColor = .black
        renderer.attach(to: v.displayLayer)
        return v
    }

    func updateUIView(_ uiView: FrameBackingView, context: Context) {
        renderer.attach(to: uiView.displayLayer)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {}
}

final class FrameBackingView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }

    var displayLayer: AVSampleBufferDisplayLayer { layer as! AVSampleBufferDisplayLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        displayLayer.videoGravity = .resizeAspect
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        displayLayer.videoGravity = .resizeAspect
    }
}
