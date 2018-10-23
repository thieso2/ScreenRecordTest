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
    
    var framesGrabbed = 0
    var framesCompressed = 0
    
    var windowTitleUpdaterTimer: Timer?
    func startWindowTitleUpdater() {
        windowTitleUpdaterTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(self.updateWindowTitle), userInfo: nil, repeats: true)
    }
    
    @objc func updateWindowTitle() {
        grabbedWindow.title = "Grabbed: \(framesGrabbed)"
        compressedWindow.title = "Compressed: \(framesCompressed)"
    }

    
    func startAll() {
        startWindowTitleUpdater()

//        screenshotLoop()
        
        grab = Grab()
        grab.delegate = self
        grab.run()

        compress = Compress(width: grab.width, height: grab.height)
        compress?.delegate = self
        
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        startAll()
    }
    
    
    var timer: Timer?
    func screenshotLoop() {
        timer = Timer.scheduledTimer(timeInterval: 1.0/10, target: self, selector: #selector(self.updateCounting), userInfo: nil, repeats: true)
    }
    
    @objc func updateCounting() {
        framesGrabbed += 1
        self.liveImage.image = screenshot()
        self.liveImage.needsDisplay = true
    }
    
    func screenshot() -> NSImage {
        let displayID = CGMainDisplayID()
        let imageRef = CGDisplayCreateImage(displayID)
        return NSImage(cgImage: imageRef!, size: NSSize(width: imageRef!.width, height: imageRef!.height))
    }

}

extension AppDelegate: CompressDelegate {
    func frameCompressd(cmSampleBuffer: CMSampleBuffer) {
        framesCompressed += 1
        sampleBufferDisplay.enqueue(cMSamplebuffer: cmSampleBuffer)
    }
}

let displayId = CGMainDisplayID()
let cs = CGDisplayCopyColorSpace(displayId)


extension AppDelegate: GrabDelegate {
    
    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
            return cgImage
        }
        return nil
    }

    func screenGrabbed(ioSurface: IOSurfaceRef) {
        framesGrabbed += 1
        compress?.compressFrame(surface: ioSurface)
        
        // DISPLAY FRAME
        let ciImage = CIImage(ioSurface: ioSurface)
        let cgImage = convertCIImageToCGImage(inputImage: ciImage)
        let iccCgImage = cgImage?.copy(colorSpace: cs)
        let nsImage = NSImage(cgImage: iccCgImage!, size: ciImage.extent.size)

//        let rep = NSCIImageRep(ciImage: ciImage)
////        let a = CGImageCreateCopyWithColorSpace(CGImageRef  , cs)
//        let nsImage = NSImage(size: ciImage.extent.size)
//        nsImage.addRepresentation(rep)
        
        DispatchQueue.main.async {
            self.liveImage.image = nsImage
            self.liveImage.needsDisplay = true
        }
    }
}

