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

    var framesGrabbed = 0
    var framesCompressed = 0

    @IBAction func showGrab(_ sender: Any) {
        grabbedWindow.makeKeyAndOrderFront(self)
    }
    
    @IBAction func showCompress(_ sender: Any) {
        compressedWindow.makeKeyAndOrderFront(self)
    }
    
    @IBAction func startstop(_ sender: Any) {
        if grab.running {
            grab.stop()
        } else {
            grab.start()
        }
    }
    
    func setup() {
        grab = Grab(displayDelegate: self)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setup()
        grab.start()
    }
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if grab.running {
            grab.stop(sender)
            return NSApplication.TerminateReply.terminateLater
        }
        return NSApplication.TerminateReply.terminateNow
   }
}

let screenColorSpace = CGDisplayCopyColorSpace(CGMainDisplayID())

extension AppDelegate: DisplayDelegate {
    
    func screenGrabbed(_ ioSurface: IOSurfaceRef) {
        framesGrabbed += 1

        guard grabbedWindow.isVisible else { return }
        
        // display frame
        let ciImage = CIImage(ioSurface: ioSurface)

        let context = CIContext(options: nil)
        var cgImage = context.createCGImage(ciImage, from: ciImage.extent)!

        // comment out the next line to see the image "as is" without the screen color profile applied
        cgImage = cgImage.copy(colorSpace: screenColorSpace)!

        let nsImage = NSImage(cgImage: cgImage, size: ciImage.extent.size)
        
        DispatchQueue.main.async {
            self.liveImage.image = nsImage
            self.liveImage.needsDisplay = true
        }
    }
    
    func frameCompressed(_ cmSampleBuffer: CMSampleBuffer) {
        framesCompressed += 1

        guard compressedWindow.isVisible else { return }

        sampleBufferDisplay.enqueue(cMSamplebuffer: cmSampleBuffer)
    }
}
