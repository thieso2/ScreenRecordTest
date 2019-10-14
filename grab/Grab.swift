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


protocol GrabDelegate {
    func screenGrabbed(ioSurface: IOSurfaceRef)
}

class Grab {
    var delegate:GrabDelegate?
    var displayStream: CGDisplayStream?
//    let backgroundQueue = DispatchQueue(label: "de.tmp8", qos: .background, target: nil)
    let width: Int
    let height: Int
    let displayId: CGDirectDisplayID
    
    var framesGrabbed = 0
    
    init() {
        displayId = CGMainDisplayID()

        //        let bounds = CGDisplayBounds(displayId)
        //        width = Int(bounds.width)
        //        height = Int(bounds.height)

        // determine the internal render resolution.
        let shot = CGDisplayCreateImage(displayId)!
        width = shot.width
        height = shot.height
        
        print("\(width)x\(height)")

        displayStream = CGDisplayStream(
            dispatchQueueDisplay: displayId,
            outputWidth: width,
            outputHeight: height,
            pixelFormat: Int32(k32BGRAPixelFormat),
            properties: nil,
            queue: .main) { (status, displayTime, frameSurface, updateRef) in
                guard let surface = frameSurface else { return }
                self.framesGrabbed += 1
                
                if self.framesGrabbed % 10 == 0 {
                    // take every 10th frame
                    self.delegate?.screenGrabbed(ioSurface: surface)
                }
        }
    }

    var running = false
    func start() {
        guard !running else { return }
        displayStream?.start()
        running = true
    }

    func stop() {
        guard running else { return }
        displayStream?.stop()
        running = false
    }
}

