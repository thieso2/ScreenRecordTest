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
    func screenGrabbed(cgImage: CGImage)
}

class Grab {
    var delegate:GrabDelegate?
    let width: Int
    let height: Int
    let displayId: CGDirectDisplayID
    let frame: CGRect
    
    init() {
        //        let bounds = CGDisplayBounds(displayId)
        //        width = Int(bounds.width)
        //        height = Int(bounds.height)
        // determine the internal render resolution.

        displayId = CGMainDisplayID()
        let shot = CGDisplayCreateImage(displayId)!
        width = shot.width
        height = shot.height

        frame = NSScreen.main!.frame
        print("\(width)x\(height)")
    }


    var timer: Timer?
    var running = false
    func start() {
        guard !running else { return }
        timer = Timer.scheduledTimer(
            timeInterval: 1,
            target: self,
            selector: #selector(self.takeShot),
            userInfo: nil, repeats: true)
        running = true
    }
    
    @objc
    func takeShot() {
//        let image = CGWindowListCreateImage(frame, .optionOnScreenBelowWindow, 7050, .nominalResolution)!
        let image = CGWindowListCreateImage(frame, .optionAll, kCGNullWindowID, .nominalResolution)!

        delegate?.screenGrabbed(cgImage: image)
    }

    func stop() {
        guard running else { return }

        timer?.invalidate()
        timer = nil
        running = false
    }
}

