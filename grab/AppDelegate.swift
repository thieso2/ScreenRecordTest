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
import AVKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var grabbedWindow: NSWindow!
    @IBOutlet weak var compressedWindow: NSWindow!
    @IBOutlet weak var playerWindow: NSWindow!
    @IBOutlet weak var liveImage: NSImageView!
    @IBOutlet weak var sampleBufferDisplay: DisplayLayer!
    
    var grab: Grab!
    var compress: Compress?
    var writer: Writer?

    var framesGrabbed = 0
    var framesCompressed = 0
    
    @IBAction func showGrab(_ sender: Any) {
        grabbedWindow.makeKeyAndOrderFront(self)
    }
    
    @IBAction func showPlayer(_ sender: Any) {
        playerWindow.makeKeyAndOrderFront(self)
    }
    
    @IBAction func reloadPlayer(_ sender: Any) {
        if let avPlayer = playerWindow.contentView as? AVPlayerView,
            let outputURL = outputURL {
            avPlayer.player = AVPlayer(url: outputURL)
        }
    }

    @IBAction func showCompress(_ sender: Any) {
        compressedWindow.makeKeyAndOrderFront(self)

    }
    
    var outputURL: URL?
    
    @IBAction func startstop(_ sender: Any) {
        if grab.running {
            writer?.close()
            grab.stop()
        } else {
            grab.start()
            outputURL = URL(fileURLWithPath: "/tmp/grab-\(Date()).mov")

            writer = Writer(
                outputURL: outputURL!,
                formatHint: compress!.formatHint!)
        }
    }
    
    func setup() {
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

        guard compressedWindow.isVisible else { return }

        sampleBufferDisplay.enqueue(cMSamplebuffer: cmSampleBuffer)
    }
}

let screenColorSpace = CGDisplayCopyColorSpace(CGMainDisplayID())

extension AppDelegate: GrabDelegate {
    
    func screenGrabbed(ioSurface: IOSurfaceRef) {
        framesGrabbed += 1
        compress?.compressFrame(surface: ioSurface)
        
        guard grabbedWindow.isVisible else { return }
        
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

