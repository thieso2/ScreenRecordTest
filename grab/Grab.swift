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
    let backgroundQueue = DispatchQueue(label: "de.tmp8", qos: .background, target: nil)
    let width: Int
    let height: Int
    let displayId: CGDirectDisplayID
    
    init() {
        displayId = CGMainDisplayID()

        //        let bounds = CGDisplayBounds(displayId)
        //        width = Int(bounds.width)
        //        height = Int(bounds.height)

        // determine the physical pixel resolution.
        let shot = CGDisplayCreateImage(displayId)!
        width = shot.width
        height = shot.height
    }

    func run() {
        displayStream = CGDisplayStream(
            dispatchQueueDisplay: displayId,
            outputWidth: width,
            outputHeight: height,
            pixelFormat: Int32(k32BGRAPixelFormat),
            properties: nil,
            queue: backgroundQueue) { (status, displayTime, frameSurface, updateRef) in
                guard let surface = frameSurface else { return }
                self.delegate?.screenGrabbed(ioSurface: surface)
        }
        
        displayStream?.start()
    }
}

