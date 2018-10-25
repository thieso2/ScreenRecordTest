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
    var writer: Writer?

    var framesGrabbed = 0
    var framesCompressed = 0
    
    var windowTitleUpdaterTimer: Timer?
    func startWindowTitleUpdater() {
        windowTitleUpdaterTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateWindowTitle), userInfo: nil, repeats: true)
    }
    
    @IBAction func startstop(_ sender: Any) {
        if grab.running {
            writer?.close()
            grab.stop()
        } else {
            grab.start()
            writer = Writer(
                outputURL: URL(fileURLWithPath: "/tmp/grab-\(Date()).mov"),
                formatHint: compress!.formatHint!)
        }
    }
    
    @objc func updateWindowTitle() {
        grabbedWindow.title = "Grabbed: \(framesGrabbed)"
        compressedWindow.title = "Compressed: \(framesCompressed)"
    }
    
    func setup() {
        startWindowTitleUpdater()

        grab = Grab()
        grab.delegate = self
        
        compress = Compress(width: grab.width, height: grab.height)
        compress?.delegate = self
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setup()
    }
}

extension AppDelegate: CompressDelegate {
    func frameCompressed(cmSampleBuffer: CMSampleBuffer) {
        framesCompressed += 1
        writer?.writeSampleBuffer(sampleBuffer: cmSampleBuffer)
        sampleBufferDisplay.enqueue(cMSamplebuffer: cmSampleBuffer)
    }
}

let screenColorSpace = CGDisplayCopyColorSpace(CGMainDisplayID())

extension AppDelegate: GrabDelegate {
    
    func screenGrabbed(ioSurface: IOSurfaceRef) {
        framesGrabbed += 1
        compress?.compressFrame(surface: ioSurface)
        
        // display frame
        let ciImage = CIImage(ioSurface: ioSurface)

        let context = CIContext(options: nil)
        var cgImage = context.createCGImage(ciImage, from: ciImage.extent)!

        // comment out the next line to see the image "as is" without
        // the screen color profile applied
//        cgImage = cgImage.copy(colorSpace: screenColorSpace)!

        let nsImage = NSImage(cgImage: cgImage, size: ciImage.extent.size)
        
        DispatchQueue.main.async {
            self.liveImage.image = nsImage
            self.liveImage.needsDisplay = true
        }
    }
}

