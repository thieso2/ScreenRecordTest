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
    var delegate: CompressDelegate?
    
    var vtCompressionSession: VTCompressionSession
    var formatHint: CMFormatDescription?
    
    init(width: Int, height: Int) {
        let codec = kCMVideoCodecType_H264

        CMVideoFormatDescriptionCreate(
            allocator: nil,
            codecType: codec,
            width: Int32(width),
            height: Int32(height),
            extensions: nil,
            formatDescriptionOut: &formatHint)

        let compressionSesionOut = UnsafeMutablePointer<VTCompressionSession?>.allocate(capacity: 1)
        
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
            compressionSessionOut: compressionSesionOut)
        assert(status == noErr)
        
        vtCompressionSession = compressionSesionOut.pointee.unsafelyUnwrapped
    }
    
    var frameNumber = 0
    
    func compressFrame(surface: IOSurfaceRef) {
        
        let pixBufferPointer = UnsafeMutablePointer<Unmanaged<CVPixelBuffer>?>.allocate(capacity: 1)
        CVPixelBufferCreateWithIOSurface(nil, surface, nil, pixBufferPointer)
        let pixelBuffer = (pixBufferPointer.pointee?.takeRetainedValue())!

        let status = VTCompressionSessionEncodeFrame(
            vtCompressionSession,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: CMTime(value: CMTimeValue(frameNumber), timescale: 600),
            duration: CMTime.invalid,
            frameProperties: nil,
            infoFlagsOut: nil) { (status, infoFlags, cmSampleBuffer) in
                guard let sampleBuffer = cmSampleBuffer else { return }
                self.delegate?.frameCompressed(cmSampleBuffer: sampleBuffer)
        }
        
        assert(status == noErr)

        frameNumber += 1
    }
}
