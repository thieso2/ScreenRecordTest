//
//  AppDelegate.swift
//  grab
//
//  Created by Thies C. Arntzen on 22.10.18.
//  Copyright © 2018 tmp8. All rights reserved.
//

import Cocoa
import CoreMediaIO
import VideoToolbox

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var grabbedWindow: NSWindow!
    @IBOutlet weak var compressedWindow: NSWindow!
    @IBOutlet weak var liveImage: NSImageView!
    @IBOutlet weak var sampleBufferDisplay: DisplayLayer!
    
    var grab: Grab!
    var compress: Compress?
    
    var framesGrabbed = 0 {
        didSet {
            DispatchQueue.main.async {
                self.grabbedWindow.title = "Grabbed: \(self.framesGrabbed)"
            }
        }
    }
    
    var framesCompressed = 0 {
        didSet {
            DispatchQueue.main.async {
                self.compressedWindow.title = "Compressed: \(self.framesCompressed)"
            }
        }
    }
    

    func startAll() {
        grab = Grab()
        grab.delegate = self
        
        compress = Compress(width: grab.width, height: grab.height)
        compress?.delegate = self
        
        grab.run()
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        startAll()
    }
}

extension AppDelegate: CompressDelegate {
    func frameCompressd(cmSampleBuffer: CMSampleBuffer) {
        framesCompressed += 1
        sampleBufferDisplay.enqueue(cMSamplebuffer: cmSampleBuffer)
    }
}

extension AppDelegate: GrabDelegate {
    func screenGrabbed(ioSurface: IOSurfaceRef) {
        framesGrabbed += 1
        compress?.compressFrame(surface: ioSurface)
        
        // DISPLAY FRAME
        let ciImage = CIImage(ioSurface: ioSurface)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: ciImage.extent.size)
        nsImage.addRepresentation(rep)
        
        DispatchQueue.main.async {
            self.liveImage.image = nsImage
            self.liveImage.needsDisplay = true
        }
    }
}

