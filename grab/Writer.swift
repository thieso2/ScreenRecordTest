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

    let ofmtCtx: AVFormatContext
    var framesWritten: Int64 = 0

    init(outputURL: URL, formatHint: CMFormatDescription) {
        
        let ouputPath = outputURL.absoluteString

        ofmtCtx = try! AVFormatContext(format: nil, filename: ouputPath)

        guard ofmtCtx.addStream() != nil else {
            fatalError("Failed allocating output stream.")
        }
        // (*video_out_stream)->time_base = (AVRational){video_in_stream->time_base.num, video_in_stream->time_base.den};
        // ostream.codecParameters.copy(from: istream.codecParameters)

        ofmtCtx.dumpFormat()

        try! ofmtCtx.openOutput(url: ouputPath, flags: .write)

        // TODO: add colorspace options
        try! ofmtCtx.writeHeader()
    }
    
    func writeSampleBuffer(sampleBuffer: CMSampleBuffer) {

        var length: size_t = 0
        var bufferDataPointer: UnsafeMutablePointer<Int8>? = nil

        CMBlockBufferGetDataPointer(CMSampleBufferGetDataBuffer(sampleBuffer)!, atOffset: 0, lengthAtOffsetOut: nil, totalLengthOut: &length, dataPointerOut: &bufferDataPointer)
        
        let data = UnsafeMutableRawPointer(bufferDataPointer)?.load(as: UnsafeMutablePointer<UInt8>.self)
        
        let pkt = AVPacket()
        
        pkt.data = data
        pkt.size = length

        pkt.pts = self.framesWritten
        pkt.dts = pkt.pts
        pkt.position = -1
        pkt.duration = 1
        pkt.streamIndex = 0

//        av_packet_rescale_ts(pkt, *time_base, st->time_base);
//        av_packet_rescale_ts(pkt, video_enc_ctx->time_base, out_stream->time_base);
        try! ofmtCtx.writeFrame(pkt)

        self.framesWritten += 1
    }
    
    func close() {
        try! ofmtCtx.writeTrailer()
        ofmtCtx.flush()
    }
}
