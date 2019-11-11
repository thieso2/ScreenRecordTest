//
//  Compress.swift
//  grab
//
//  Created by Thies C. Arntzen on 23.10.18.
//  Copyright © 2018 tmp8. All rights reserved.
//

import Foundation
import CoreMedia
import AppKit
import CoreImage
import VideoToolbox
import Accelerate

protocol CompressDelegate {
    func frameCompressed(cmSampleBuffer: CMSampleBuffer)
}

class Compress {
    var displayDelegate:DisplayDelegate?

    let codec = kCMVideoCodecType_H264
    var width: Int
    var height: Int
    var basePath: String
    var frameCount = 0
    
    var vtCompressionSession: VTCompressionSession?
    var formatHint: CMFormatDescription?

    var writer: Writer?

    var running = false

    init(width: Int, height: Int, basePath: String) {
        self.width = width
        self.height = height
        self.basePath = basePath

        CMVideoFormatDescriptionCreate(
            allocator: nil,
            codecType: codec,
            width: Int32(width),
            height: Int32(height),
            extensions: [
                kCMFormatDescriptionExtension_ColorPrimaries: kCMFormatDescriptionColorPrimaries_ITU_R_709_2,
                kCMFormatDescriptionExtension_TransferFunction: kCMFormatDescriptionTransferFunction_ITU_R_709_2,
                kCMFormatDescriptionExtension_YCbCrMatrix: kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2,
                ] as CFDictionary,
            formatDescriptionOut: &formatHint)
    }
    
    func start() {
        guard !running else { return }

        let compressionSessionOut = UnsafeMutablePointer<VTCompressionSession?>.allocate(capacity: 1)
        
        let status = VTCompressionSessionCreate(
            allocator: nil,
            width: Int32(width),
            height: Int32(height),
            codecType: codec,
            encoderSpecification: [
                kVTVideoEncoderSpecification_EnableHardwareAcceleratedVideoEncoder: kCFBooleanTrue
                ] as CFDictionary,
            imageBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey: width,
                kCVPixelBufferHeightKey: height,
                ] as CFDictionary,
            compressedDataAllocator: nil,
            outputCallback: nil,
            refcon: nil,
            compressionSessionOut: compressionSessionOut)

        assert(status == noErr)
        
        vtCompressionSession = compressionSessionOut.pointee.unsafelyUnwrapped
        
        writer = Writer(outputURL: URL(fileURLWithPath: "\(basePath)/grab-\(Date()).mp4"), formatHint: formatHint!)

        running = true
    }

    func stop(_ sender: NSApplication? = nil) {
        guard running else { return }
        
        VTCompressionSessionCompleteFrames(vtCompressionSession!, untilPresentationTimeStamp: CMTime())

        writer?.close()
        if (sender != nil) {
            sender!.reply(toApplicationShouldTerminate: true)
        }
        running = false
    }

    func newFrame(_ surface: IOSurfaceRef) {

        guard running else { return }

        let pixBufferPointer = UnsafeMutablePointer<Unmanaged<CVPixelBuffer>?>.allocate(capacity: 1)
        CVPixelBufferCreateWithIOSurface(nil, surface, nil, pixBufferPointer)
        let pixelBuffer = (pixBufferPointer.pointee?.takeRetainedValue())!

        let status = VTCompressionSessionEncodeFrame(
            vtCompressionSession!,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: CMTime(value: CMTimeValue(frameCount), timescale: 60),
            duration: CMTime.invalid,
            frameProperties: nil,
            infoFlagsOut: nil) { (status, infoFlags, cmSampleBuffer) in
                guard let sampleBuffer = cmSampleBuffer else { return }
                DispatchQueue.main.async {
                    self.displayDelegate?.frameCompressed(sampleBuffer)
                }
                try! self.writer!.writeSampleBuffer(sampleBuffer)
            }

        assert(status == noErr)

        frameCount += 1
    }
}
