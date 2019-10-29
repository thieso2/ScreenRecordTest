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

class Writer {

    let formatContext: AVFormatContext
    var framesWritten: Int64 = 0
    var open = false

    init(outputURL: URL, formatHint: CMFormatDescription) {
        
        print("Writer.init()")

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
        
        let stream = formatContext.addStream()!
        stream.codecParameters.copy(from: codecContext)

        stream.timebase = AVRational(num: 1, den: 600)

        formatContext.dumpFormat(url: nil, isOutput: true)

        try! formatContext.openOutput(url: outputPath, flags: .write)

        try! formatContext.writeHeader()

        open = true
    }
    
    private func logPacket(_ pkt: AVPacket, _ formatContext: AVFormatContext) {

        print("pts:\(pkt.pts) dts:\(pkt.dts) data length:\(pkt.size)")
        
        var b1 = UnsafeMutableRawPointer(pkt.data)!
        for _ in 1...30 {
            print(String(format:"%02X", b1.load(as: UInt8.self)), separator: "", terminator: " ")
            b1 += 1
        }
        print("")
    }

    func writeSampleBuffer(sampleBuffer: CMSampleBuffer) {

        print("Writer.writeSampleBuffer(), framesWritten: \(framesWritten)")

        guard open else { return }

        var length: size_t = 0
        var bufferDataPointer: UnsafeMutablePointer<Int8>? = nil

        CMBlockBufferGetDataPointer(CMSampleBufferGetDataBuffer(sampleBuffer)!, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &bufferDataPointer)
        
        let description = CMSampleBufferGetFormatDescription(sampleBuffer)!
        
        var lengthCodeSize: Int32 = 0
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(description, parameterSetIndex: 0, parameterSetPointerOut: nil, parameterSetSizeOut: nil, parameterSetCountOut: nil, nalUnitHeaderLengthOut: &lengthCodeSize)

        bufferDataPointer?.withMemoryRebound(to: UInt8.self, capacity: length) { to in
            let pkt = AVPacket()
            pkt.data = to
            pkt.size = length
            pkt.pts = framesWritten
            pkt.dts = pkt.pts
            pkt.position = -1
            pkt.duration = 1
            pkt.streamIndex = 0

            logPacket(pkt, formatContext)
            
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
