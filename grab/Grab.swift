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

class Grab {
    var displayStream: CGDisplayStream?
    let backgroundQueue = DispatchQueue(label: "de.tmp8", qos: .background, target: nil)
    
    func run(previewCallback: @escaping (_ image: NSImage) -> Void) {
        let displayId = CGMainDisplayID()
        let bounds = CGDisplayBounds(displayId)
        
        displayStream = CGDisplayStream(
            dispatchQueueDisplay: displayId,
            outputWidth: Int(bounds.width),
            outputHeight: Int(bounds.height),
            pixelFormat: Int32(k32BGRAPixelFormat),
            properties: nil,
            queue: backgroundQueue) { (status, displayTime, frameSurface, updateRef) in
                guard let surface = frameSurface else { return }
                
                let ciImage = CIImage(ioSurface: surface)
                let rep = NSCIImageRep(ciImage: ciImage)
                let nsImage = NSImage(size: ciImage.extent.size)
                nsImage.addRepresentation(rep)
                
                previewCallback(nsImage)
        }
        
        displayStream?.start()
    }
}
