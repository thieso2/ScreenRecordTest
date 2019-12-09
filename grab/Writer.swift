//
//  Writer.swift
//  grab
//
//  Created by Thies C. Arntzen on 25.10.18.
//  Copyright © 2018 tmp8. All rights reserved.
//

import Foundation
import CoreMediaIO
import SwiftFFmpeg

enum WriterError: Error {
    case invalidState(String)
}

class Writer {

    let formatContext: AVFormatContext
    let stream: AVStream
    let codecContext: AVCodecContext
    var framesWritten: Int64 = 0
    var open = false
    let filterContext: AVBitStreamFilterContext
    var startCode: [UInt8] = [0, 0, 0, 1]
    let startCodeSize: UInt32 = 4
    var playerDelegate:PlayerDelegate?
    var outputURL: URL

    private func logPacket(_ pkt: AVPacket, _ formatContext: AVFormatContext) {

        print("pts:\(pkt.pts), dts:\(pkt.dts), keyframe: \(pkt.flags.rawValue & AVPacket.Flag.key.rawValue), length:\(pkt.size)")
    }
    
    private func dumpBuffer(buf: UnsafeMutablePointer<UInt8>, bufSize: Int = 0) {
        var b = UnsafeMutableRawPointer(buf)!
        for i in 0..<bufSize {
            print(String(format:"%02X", b.load(as: UInt8.self)), separator: "", terminator: " ")
            b += 1
            if ((i + 1) % 16 == 0) {
                print("")
            }
        }
        print("")
    }

    init(_ playerDelegate:PlayerDelegate?, outputURL: URL, formatDescription: CMFormatDescription) {
        
        // support sending notification of new URL available for playback
        self.playerDelegate = playerDelegate
        self.outputURL = outputURL

        AVLog.level = AVLog.Level.info

        let outputPath = outputURL.absoluteString

        formatContext = try! AVFormatContext(format: nil, formatName: nil, filename: outputPath)

        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)

        // initialize stream codec params from the codec context
        let codec = AVCodec.findDecoderById(AVCodecID.H264)
        codecContext = AVCodecContext(codec: codec)
        codecContext.width = Int(dimensions.width)
        codecContext.height = Int(dimensions.height)
        codecContext.framerate = AVRational(num: 60, den: 1)
        codecContext.timebase = AVRational(num: codecContext.framerate.den, den: codecContext.framerate.num)
        codecContext.flags = AVCodecContext.Flag.globalHeader

        stream = formatContext.addStream()!
        stream.codecParameters.copy(from: codecContext)

        stream.timebase = AVRational(num: 1, den: 600)

        if let property = CMFormatDescriptionGetExtension(formatDescription, extensionKey: kCMFormatDescriptionExtension_ICCProfile) {
            let iccData = property as! CFData
            let size = CFDataGetLength(iccData)
            let data: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer.allocate(capacity: Int(size))
            try! stream.addSideData(type: AVPacketSideDataType.iccProfile, data: data, size: size)
        }

        formatContext.dumpFormat(url: nil, isOutput: true)

        // add this to ensure AVCC atom populated
        let filter = AVBitStreamFilter(name: "extract_extradata")!
        filterContext = AVBitStreamFilterContext(filter: filter)
        filterContext.inParameters.copy(from: stream.codecParameters)
        filterContext.time_base_in = stream.timebase
        try! filterContext.initialize()
        stream.codecParameters.copy(from: filterContext.outParameters)
        stream.timebase = filterContext.time_base_out

        try! formatContext.openOutput(url: outputPath, flags: .write)

        try! formatContext.writeHeader(options: ["movflags": "write_colr+prefer_icc+allow_small_timescale+frag_custom+faststart",
                                                 "use_editlist": "0"])

        open = true

        playerDelegate?.mediaAvailable(outputURL)
    }

    private func getParamsSize(_ description:CMFormatDescription) -> UInt32 {

        var totalSize: UInt32 = 0
        var paramCount: Int = 0

        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           parameterSetIndex: 0,
                                                           parameterSetPointerOut: nil,
                                                           parameterSetSizeOut: nil,
                                                           parameterSetCountOut: &paramCount,
                                                           nalUnitHeaderLengthOut: nil)
        for i in 0..<paramCount {
            var paramsSize: Int = 0

            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                               parameterSetIndex: i,
                                                               parameterSetPointerOut: nil,
                                                               parameterSetSizeOut: &paramsSize,
                                                               parameterSetCountOut: nil,
                                                               nalUnitHeaderLengthOut: nil)
            totalSize += UInt32(paramsSize) + startCodeSize
        }
        return totalSize
    }

    private func countNalus(_ sampleBuffer: CMSampleBuffer, lengthCodeSize: UInt32) throws -> Int {
        
        var offset: UInt32 = 0
        var naluCount = 0

        let inBufSize = CMSampleBufferGetTotalSampleSize(sampleBuffer)
        let block = CMSampleBufferGetDataBuffer(sampleBuffer)!

        while (offset < inBufSize) {
            var naluLen: UInt32
            var dataSize: UInt32 = 0

            CMBlockBufferCopyDataBytes(block, atOffset: Int(offset), dataLength: Int(lengthCodeSize), destination: &dataSize)
            dataSize = CFSwapInt32(dataSize)

            naluLen = dataSize + lengthCodeSize
            offset += naluLen
            naluCount += 1
        }
        return naluCount
    }

    private func copyParamSets(_ description:CMFormatDescription, outBuf: UnsafeMutablePointer<UInt8>, outBufSize: UInt32) throws {

        var paramCount: Int = 0
        var nalType: UInt8 = 0

        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                        parameterSetIndex: 0,
                                                        parameterSetPointerOut: nil,
                                                        parameterSetSizeOut: nil,
                                                        parameterSetCountOut: &paramCount,
                                                        nalUnitHeaderLengthOut: nil)
        var offset: UInt32 = 0
        for i in 0..<paramCount {
            var nextOffset: UInt32 = 0
            var params: UnsafePointer<UInt8>?
            var paramsSize: Int = 0
            var currentDest: UnsafeMutablePointer<UInt8>?
            
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                               parameterSetIndex: i,
                                                               parameterSetPointerOut: &params,
                                                               parameterSetSizeOut: &paramsSize,
                                                               parameterSetCountOut: nil,
                                                               nalUnitHeaderLengthOut: nil)
            nextOffset = offset + startCodeSize + UInt32(paramsSize)
            if (outBufSize < nextOffset) {
                throw WriterError.invalidState("Output buffer too small for param sets!")
            }
            
            currentDest = outBuf + Int(offset)
            currentDest!.initialize(from: startCode, count: Int(startCodeSize))

            offset += startCodeSize
            currentDest = outBuf + Int(offset)
            currentDest!.initialize(from: params!, count: paramsSize)

            let b = UnsafeMutableRawPointer(currentDest)!
            nalType = b.load(as: UInt8.self)
            nalType &= 0x1F

            offset = nextOffset
        }
    }

    private func copyReplaceLengthCodes(_ sampleBuffer: CMSampleBuffer, lengthCodeSize: UInt32, outBuf: UnsafeMutablePointer<UInt8>, outBufSize: UInt32) throws {

        let srcSize: UInt32 = UInt32(CMSampleBufferGetTotalSampleSize(sampleBuffer))
        var remainingSrcSize: UInt32 = srcSize
        var remainingDstSize: UInt32 = outBufSize
        var srcOffset = 0
        var currentDest: UnsafeMutablePointer<UInt8>? = outBuf

        let block = CMSampleBufferGetDataBuffer(sampleBuffer)!
        
        while (remainingSrcSize > 0) {
            var currSrcLen: UInt32
            var currDstLen: UInt32
            var dataSize: UInt32 = 0

            CMBlockBufferCopyDataBytes(block, atOffset: srcOffset, dataLength: Int(lengthCodeSize), destination: &dataSize)
            dataSize = CFSwapInt32(dataSize)

            currSrcLen = dataSize + lengthCodeSize
            currDstLen = dataSize + startCodeSize
            if (remainingSrcSize < currSrcLen) {
                throw WriterError.invalidState("Source buffer too small to read from!")
            }
            if (remainingDstSize < currDstLen) {
                throw WriterError.invalidState("Dest buffer too small to write to!")
            }

            currentDest?.initialize(from: startCode, count: Int(startCodeSize))
            CMBlockBufferCopyDataBytes(block, atOffset: srcOffset + Int(lengthCodeSize), dataLength: Int(dataSize), destination: currentDest! + Int(startCodeSize))

            srcOffset += Int(currSrcLen)
            currentDest = currentDest! + Int(currDstLen)
            remainingSrcSize -= currSrcLen
            remainingDstSize -= currDstLen
        }
    }

    func writeSampleBuffer(_ sampleBuffer: CMSampleBuffer) throws {

        guard open else { return }

        let description:CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!

        let paramsSize = getParamsSize(description)

        if (stream.codecParameters.extradataSize == 0) {
            stream.codecParameters.extradata = UnsafeMutablePointer.allocate(capacity: Int(paramsSize))
            stream.codecParameters.extradataSize = Int(paramsSize)
            try! copyParamSets(description, outBuf: stream.codecParameters.extradata!, outBufSize: paramsSize)
        }

        var isKeyframe:Bool = false

        let attachmentsArray:CFArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)!
        if (CFArrayGetCount(attachmentsArray) > 0) {
            let element = CFArrayGetValueAtIndex(attachmentsArray, 0)
            let dict:CFDictionary = unsafeBitCast(element, to: CFDictionary.self)

            let boolPtr = UnsafeMutablePointer<UnsafeRawPointer?>.allocate(capacity: 0)

            if (CFDictionaryGetValueIfPresent(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque(), boolPtr) == true) {
                let notSync = Unmanaged<NSNumber>.fromOpaque(boolPtr.pointee!).takeUnretainedValue()
                isKeyframe = !notSync.boolValue
            } else {
                isKeyframe = true
            }
        }
        
        let inBufSize: UInt32 = UInt32(CMSampleBufferGetTotalSampleSize(sampleBuffer))

        var lengthCodeSize: Int32 = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           parameterSetIndex: 0,
                                                           parameterSetPointerOut: nil,
                                                           parameterSetSizeOut: nil,
                                                           parameterSetCountOut: nil,
                                                           nalUnitHeaderLengthOut: &lengthCodeSize)

        let naluCount = try! countNalus(sampleBuffer, lengthCodeSize: UInt32(lengthCodeSize))
        let outBufSize = inBufSize + UInt32((naluCount * Int((startCodeSize - UInt32(lengthCodeSize)))))

        let outBuf: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer.allocate(capacity: Int(outBufSize))

        let pkt = AVPacket()
        pkt.data = outBuf
        pkt.size = Int(outBufSize)
        pkt.position = -1
        pkt.duration = 1
        pkt.pts = framesWritten
        pkt.dts = pkt.pts
        pkt.rescaleTimestamp(from: codecContext.timebase, to: stream.timebase)

        if (isKeyframe) {
            pkt.flags = AVPacket.Flag(rawValue: (pkt.flags.rawValue | AVPacket.Flag.key.rawValue))
            logPacket(pkt, formatContext)
        }

        try! copyReplaceLengthCodes(sampleBuffer, lengthCodeSize: UInt32(lengthCodeSize), outBuf: outBuf, outBufSize: UInt32(pkt.size))

        try! filterContext.sendPacket(pkt)

        while (true) {
            do {
                try filterContext.receivePacket(pkt)
            } catch let err as AVError where err == .eof {
                break
            } catch let err as AVError where err == .tryAgain {
                break
            } catch {
                print("Unexpected error from receivePacket()")
            }

            // logPacket(pkt, formatContext)

            try! formatContext.writeFrame(pkt)
            framesWritten += 1
        }
    }
    
    func flush() {
        guard open else { return }
        try! formatContext.writeFrame(nil)
        print("Muxer flushed!")
        playerDelegate?.mediaFlushed()
    }

    func close() {

        guard open else { return }
        open = false
        
        try! formatContext.writeTrailer()
        formatContext.pb?.flush()
        formatContext.flush()
        print("Trailer written!")
    }
}
