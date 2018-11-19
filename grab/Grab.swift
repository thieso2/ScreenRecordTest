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
    let frame: CGRect
    
    init() {
        frame = NSScreen.main!.frame
        width = Int(frame.width)
        height = Int(frame.height)
        print("Grab.init \(frame)")
    }
    
    func screenshot() -> CGImage? {
        //        let image = CGWindowListCreateImage(frame, .optionOnScreenBelowWindow, 7050, .bestResolution)!
        // use .nominalResolution for non-retina
        return CGWindowListCreateImage(frame, .optionOnScreenOnly, kCGNullWindowID, .nominalResolution)
    }
    
    var timer: Timer?
    var running = false
    func start() {
        guard !running else { return }
        timer = Timer.scheduledTimer(
            timeInterval: 0.1,
            target: self,
            selector: #selector(self.takeShot),
            userInfo: nil, repeats: true)
        running = true
    }
    
    @objc
    func takeShot() {
        if let image = screenshot() {
            delegate?.screenGrabbed(cgImage: image)
        } else {
            assert(false)
        }
    }
    
    func stop() {
        guard running else { return }
        
        timer?.invalidate()
        timer = nil
        running = false
    }
}

