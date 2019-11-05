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
    var framesWritten: Int64 = 0
    var open = false
    let filterContext: AVBitStreamFilterContext
    var startCode: [UInt8] = [0, 0, 0, 1]
    let startCodeSize = 4

    init(outputURL: URL, formatHint: CMFormatDescription) {
        
        print("Writer.init()")

        AVLog.level = AVLog.Level.trace

        let outputPath = outputURL.absoluteString

        formatContext = try! AVFormatContext(format: nil, formatName: nil, filename: outputPath)

        let dimensions = CMVideoFormatDescriptionGetDimensions(formatHint)
        print("\(dimensions.width)x\(dimensions.height)")

        // initialize stream codec params from the codec context
        let codec = AVCodec.findEncoderById(AVCodecID.H264)
        let codecContext = AVCodecContext(codec: codec)
        codecContext.width = Int(dimensions.width)
        codecContext.height = Int(dimensions.height)
        codecContext.framerate = AVRational(num: 1, den: 600)
        codecContext.timebase = AVRational(num: codecContext.framerate.den, den: codecContext.framerate.num)
        
        stream = formatContext.addStream()!
        stream.codecParameters.copy(from: codecContext)

        stream.timebase = AVRational(num: 1, den: 600)

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

        try! formatContext.writeHeader()

        open = true
    }
    
    private func logPacket(_ pkt: AVPacket, _ formatContext: AVFormatContext) {

        print("pts:\(pkt.pts), dts:\(pkt.dts), keyframe: \(pkt.flags.rawValue & AVPacket.Flag.key.rawValue), length:\(pkt.size)")
        
        var b1 = UnsafeMutableRawPointer(pkt.data)!
        for _ in 1...30 {
            print(String(format:"%02X", b1.load(as: UInt8.self)), separator: "", terminator: " ")
            b1 += 1
        }
        print("")
    }

    private func getParamsSize(_ description:CMFormatDescription) -> Int {

        var totalSize = 0
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
            totalSize += paramsSize + startCodeSize
        }
        return totalSize
    }

    private func countNalus(_ sampleBuffer: CMSampleBuffer, lengthCodeSize: Int32) -> Int {
        
        var offset: Int32 = 0
        var naluCount = 0
        var sizeBuf = Array<UInt8>(repeating: 0, count: 4)

        let inBufSize = CMSampleBufferGetTotalSampleSize(sampleBuffer)
        let block = CMSampleBufferGetDataBuffer(sampleBuffer)!

        while (offset < inBufSize) {
            var naluLen: Int32
            var dataSize: Int32 = 0

            CMBlockBufferCopyDataBytes(block, atOffset: Int(offset), dataLength: Int(lengthCodeSize), destination: &sizeBuf)

            for i in 0..<lengthCodeSize {
                dataSize <<= 8
                dataSize |= Int32(sizeBuf[Int(i)])
            }

            naluLen = dataSize + lengthCodeSize
            offset += naluLen
            naluCount += 1
        }
        return naluCount
    }

    private func copyParamSets(_ description:CMFormatDescription, outBuf: UnsafeMutablePointer<UInt8>, outBufSize: Int) throws {
        
        print("Writer.copyParamSets()")

        var paramCount: Int = 0

        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                        parameterSetIndex: 0,
                                                        parameterSetPointerOut: nil,
                                                        parameterSetSizeOut: nil,
                                                        parameterSetCountOut: &paramCount,
                                                        nalUnitHeaderLengthOut: nil)
        for i in 0..<paramCount {
            var offset: Int = 0
            var nextOffset: Int = 0
            var params: UnsafePointer<UInt8>?
            var paramsSize: Int = 0
            var currentDest: UnsafeMutablePointer<UInt8>?
            
            CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                               parameterSetIndex: i,
                                                               parameterSetPointerOut: &params,
                                                               parameterSetSizeOut: &paramsSize,
                                                               parameterSetCountOut: nil,
                                                               nalUnitHeaderLengthOut: nil)
            nextOffset = offset + startCodeSize + paramsSize
            if (outBufSize < nextOffset) {
                throw WriterError.invalidState("Output buffer too small for param sets!")
            }
            
            currentDest = outBuf + offset
            currentDest?.initialize(from: startCode, count: startCodeSize)

            offset += startCodeSize
            currentDest = outBuf + offset
            currentDest?.initialize(from: params!, count: paramsSize)
            offset = nextOffset
        }
    }

    private func copyReplaceLengthCodes(_ sampleBuffer: CMSampleBuffer, lengthCodeSize: Int32, outBuf: UnsafeMutablePointer<UInt8>, outBufSize: Int) throws {

        print("Writer.copyReplaceLengthCodes()")

        let srcSize = CMSampleBufferGetTotalSampleSize(sampleBuffer)
        var remainingSrcSize = srcSize
        var remainingDstSize = outBufSize
        var srcOffset = 0
        var currentDest: UnsafeMutablePointer<UInt8>? = outBuf

        let sizeBuf: [UInt8] = [0, 0, 0, 0]
        var nalType: UInt8 = 0
        let block = CMSampleBufferGetDataBuffer(sampleBuffer)!

        while (remainingSrcSize > 0) {
            var currSrcLen: Int
            var currDstLen: Int
            var dataSize: Int32 = 0

            CMBlockBufferCopyDataBytes(block, atOffset: srcOffset, dataLength: Int(lengthCodeSize), destination: UnsafeMutableRawPointer(mutating: sizeBuf))
            CMBlockBufferCopyDataBytes(block, atOffset: srcOffset + Int(lengthCodeSize), dataLength: 1, destination: &nalType)

            nalType &= 0x1F
            print("nalType: \(nalType)")
            
            for i in 0..<lengthCodeSize {
                dataSize <<= 8
                dataSize |= Int32(sizeBuf[Int(i)])
            }

            currSrcLen = Int(dataSize) + Int(lengthCodeSize)
            currDstLen = Int(dataSize) + startCodeSize
            if (remainingSrcSize < currSrcLen) {
                throw WriterError.invalidState("Source buffer too small to read from!")
            }
            if (remainingDstSize < currDstLen) {
                throw WriterError.invalidState("Dest buffer too small to write to!")
            }

            currentDest?.initialize(from: startCode, count: startCodeSize)
            CMBlockBufferCopyDataBytes(block, atOffset: srcOffset + Int(lengthCodeSize), dataLength: Int(dataSize), destination: currentDest! + startCodeSize)

            srcOffset += currSrcLen
            currentDest = currentDest! + currDstLen
            remainingSrcSize -= currSrcLen
            remainingDstSize -= currDstLen
        }
    }

    func writeSampleBuffer(sampleBuffer: CMSampleBuffer) {

        print("Writer.writeSampleBuffer(), framesWritten: \(framesWritten)")

        guard open else { return }

        let description:CMFormatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)!

        let paramsSize = getParamsSize(description)
        print("paramsSize: \(paramsSize)")

        if (self.framesWritten == 0) {
            stream.codecParameters.extradata = UnsafeMutablePointer.allocate(capacity: paramsSize)
            stream.codecParameters.extradataSize = paramsSize

            try! copyParamSets(description, outBuf: stream.codecParameters.extradata!, outBufSize: paramsSize)
        }
            
        var isKeyframe:Bool = false

        let attachmentsArray:CFArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false)!
        if (CFArrayGetCount(attachmentsArray) > 0) {
            let element = CFArrayGetValueAtIndex(attachmentsArray, 0)
            let dict:CFDictionary = unsafeBitCast(element, to: CFDictionary.self)
            
            if let ptr = CFDictionaryGetValue(dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque()) {
                let notSync = Unmanaged<NSNumber>.fromOpaque(ptr).takeUnretainedValue()
                isKeyframe = !notSync.boolValue
            }
            else {
                isKeyframe = true
            }
        }
        
        let inBufSize = CMSampleBufferGetTotalSampleSize(sampleBuffer)

        var lengthCodeSize: Int32 = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description,
                                                           parameterSetIndex: 0,
                                                           parameterSetPointerOut: nil,
                                                           parameterSetSizeOut: nil,
                                                           parameterSetCountOut: nil,
                                                           nalUnitHeaderLengthOut: &lengthCodeSize)

        let naluCount = countNalus(sampleBuffer, lengthCodeSize: lengthCodeSize)
        print("naluCount: \(naluCount)")

        var headerSize = 0
        if (isKeyframe) {
            headerSize = paramsSize
        }
        let outBufSize = headerSize + inBufSize + (naluCount * (startCodeSize - Int(lengthCodeSize)))

        let outBuf: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer.allocate(capacity: outBufSize)

        let pkt = AVPacket()
        pkt.data = outBuf
        pkt.size = outBufSize
        pkt.pts = framesWritten
        pkt.dts = pkt.pts
        pkt.position = -1
        pkt.duration = 1
        pkt.streamIndex = 0

        if (isKeyframe) {
            try! copyParamSets(description, outBuf: outBuf, outBufSize: outBufSize)
            pkt.flags = AVPacket.Flag(rawValue: (pkt.flags.rawValue | AVPacket.Flag.key.rawValue))
        }

        try! copyReplaceLengthCodes(sampleBuffer, lengthCodeSize: lengthCodeSize, outBuf: outBuf, outBufSize: pkt.size - headerSize)

        logPacket(pkt, formatContext)
            
        try! self.filterContext.sendPacket(pkt)
        while (true) {
            do {
                try self.filterContext.receivePacket(pkt)
            } catch let err as AVError where err == .eof {
                break
            } catch let err as AVError where err == .tryAgain {
                break
            } catch {
                print("Unexpected error from receivePacket()")
            }
            
            try! formatContext.writeFrame(pkt)
        }

        self.framesWritten += 1
    }
    
    func close() {
        print("Writer.close()")

        guard open else { return }
        open = false
        
        try! formatContext.writeTrailer()
        formatContext.flush()
    }
}
