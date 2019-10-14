//
//  Writer.swift
//  grab
//
//  Created by Thies C. Arntzen on 25.10.18.
//  Copyright © 2018 tmp8. All rights reserved.
//

import Foundation
import CoreMediaIO
import AVKit
import SwiftFFmpeg

class Writer {
    let avAssetWriterInput: AVAssetWriterInput
    let avAssetWriter: AVAssetWriter
    
    init(outputURL: URL, formatHint: CMFormatDescription) {
        avAssetWriterInput = AVAssetWriterInput(
            mediaType: AVMediaType.video,
            outputSettings: nil,
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
