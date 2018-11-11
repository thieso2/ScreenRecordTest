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
    
    @IBAction func showGrab(_ sender: Any) {
        grabbedWindow.makeKeyAndOrderFront(self)
    }
    
    @IBAction func showCompress(_ sender: Any) {
        compressedWindow.makeKeyAndOrderFront(self)

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
    
    var timer: Timer?
    
    func setup() {
        grab = Grab()
        grab.delegate = self
        
        compress = Compress(width: grab.width, height: grab.height)
        compress?.delegate = self

        timer = Timer.scheduledTimer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(self.printInfo),
            userInfo: nil, repeats: true)
    }
    
    @objc
    func printInfo() {
        print(framesGrabbed, framesCompressed)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        for w in Windows.all {
            print(w.appName, w.name, w.number, w.pid, w.bounds)
        }

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


extension AppDelegate: GrabDelegate {
    func screenGrabbed(cgImage: CGImage) {
        framesGrabbed += 1
        
        if let pix = cgImage.pixelBuffer() {
            compress?.compressFrame(pixelBuffer: pix)
        }
        
        guard grabbedWindow.isVisible else { return }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

        DispatchQueue.main.async {
            self.liveImage.image = nsImage
            self.liveImage.needsDisplay = true
        }
    }
}

extension CGImage {
    
    func pixelBuffer() -> CVPixelBuffer? {

        var pxbuffer: CVPixelBuffer?

        
        // https://github.com/twilio/video-quickstart-swift/blob/master/ScreenCapturerExample/ExampleScreenCapturer.swift

        let data = dataProvider?.data
        let baseAddress = CFDataGetBytePtr(data!)
        let unmanagedData = Unmanaged<CFData>.passRetained(data!)

        CVPixelBufferCreateWithBytes(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            UnsafeMutableRawPointer(mutating: baseAddress!),
            bytesPerRow,
            {
                (releaseContext, baseAddress) in
                let contextData = Unmanaged<CFData>.fromOpaque(releaseContext!)
                contextData.release()
            },
            unmanagedData.toOpaque(),
            nil,
            &pxbuffer
        )
        
        assert(pxbuffer != nil)
        
        return pxbuffer
    }
}
