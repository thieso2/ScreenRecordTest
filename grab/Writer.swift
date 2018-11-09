//
//  Writer.swift
//  grab
//
//  Created by Thies C. Arntzen on 25.10.18.
//  Copyright © 2018 tmp8. All rights reserved.
//

import Foundation
import CoreMediaIO
import  AVKit

class Writer {
    let avAssetWriterInput: AVAssetWriterInput
    let avAssetWriter: AVAssetWriter
    
    init(outputURL: URL, formatHint: CMFormatDescription) {
//        let compressionSettings = [
//            AVVideoColorPrimariesKey:AVVideoColorPrimaries_ITU_R_709_2,
//            AVVideoTransferFunctionKey:AVVideoTransferFunction_ITU_R_709_2,
//            AVVideoYCbCrMatrixKey:AVVideoYCbCrMatrix_ITU_R_709_2
//        ]
//
//        let videoOutputSettings: [String:Any] = [
//            AVVideoCodecKey: AVVideoCodecType.h264,
//            AVVideoColorPropertiesKey: compressionSettings
//        ]
        
        avAssetWriterInput = AVAssetWriterInput(
            mediaType: AVMediaType.video,
            outputSettings: nil, // videoOutputSettings,
            sourceFormatHint: formatHint)
        
        avAssetWriter = try! AVAssetWriter(
            outputURL: outputURL,
            fileType: AVFileType.mov)

        avAssetWriter.add(avAssetWriterInput)
        
        avAssetWriter.startWriting()
        avAssetWriter.startSession(atSourceTime: CMTime.zero)
    }
    
    func writeSampleBuffer(sampleBuffer: CMSampleBuffer) {
        avAssetWriterInput.append(sampleBuffer)
    }
    
    func close() {
        avAssetWriterInput.markAsFinished()
        avAssetWriter.finishWriting {
            print("done")
        }
    }
}
