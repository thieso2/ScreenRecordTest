//
//  Grab.swift
//  grab
//
//  Created by Thies C. Arntzen on 22.10.18.
//  Copyright © 2018 tmp8. All rights reserved.
//

import Foundation
import CoreMedia
import AppKit
import CoreImage


protocol DisplayDelegate {
    func screenGrabbed(_ surface: IOSurfaceRef)
    func frameCompressed(_ sampleBuffer: CMSampleBuffer)
}

protocol PlayerDelegate {
    func mediaAvailable(_ url: URL)
    func mediaFlushed()
}

class Grab {
    var displayDelegate:DisplayDelegate?
    
    var displayStream: CGDisplayStream!
    var compress: Compress!

    var frameCount = 0
    var running = false

    init(displayDelegate:DisplayDelegate?, playerDelegate:PlayerDelegate?) {
        
        // support sending grabbed frames for display
        self.displayDelegate = displayDelegate

        let displayId = CGMainDisplayID()

        let shot = CGDisplayCreateImage(displayId)!
        let width = shot.width
        let height = shot.height
        
        print("\(width)x\(height)")

        // setup compressor
        compress = Compress(displayDelegate, playerDelegate, width: width, height: height)

        // send grabbed frames to display and compress
        displayStream = CGDisplayStream(
            dispatchQueueDisplay: displayId,
            outputWidth: width,
            outputHeight: height,
            pixelFormat: Int32(k32BGRAPixelFormat),
            properties: nil,
            queue: .main) { (status, displayTime, frameSurface, updateRef) in
                guard let surface = frameSurface else { return }
                self.frameCount += 1
                
                // take every 10th frame
                if self.frameCount % 10 == 0 {

                    // send for display
                    self.displayDelegate?.screenGrabbed(surface)
                    
                    // send for compression
                    self.compress.newFrame(surface)
                }
        }
    }

    func start() {
        guard !running else { return }
        displayStream.start()
        compress.start()
        running = true
    }

    func stop(_ sender: NSApplication? = nil) {
        guard running else { return }
        displayStream.stop()
        compress.stop(sender)
        running = false
    }

    func flush() {
        guard running else { return }
        compress.flush()
    }
}
