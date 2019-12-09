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
    
    let screenColorSpace = CGDisplayCopyColorSpace(CGMainDisplayID())

    var grab: Grab!
    var outputURL: URL?
    var player: AVPlayer?

    var framesGrabbed = 0
    var framesCompressed = 0

    @IBAction func showGrab(_ sender: Any) {
        grabbedWindow.makeKeyAndOrderFront(self)
    }
    
    @IBAction func showPlayer(_ sender: Any) {
        playerWindow.makeKeyAndOrderFront(self)
    }
    
    @IBAction func reloadPlayer(_ sender: Any) {
        guard outputURL != nil else { return }

        print("\(outputURL!) is being loaded")
        let playerItem = AVPlayerItem(url: outputURL!)
        player?.replaceCurrentItem(with: playerItem)
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
        grab = Grab(displayDelegate: self, playerDelegate: self)

        if let avPlayerView = playerWindow.contentView as? AVPlayerView {
            player = AVPlayer()
            avPlayerView.player = player
            
            player!.addObserver(self, forKeyPath: #keyPath(AVPlayer.status), options: [.new, .initial], context: nil)
            player!.addObserver(self, forKeyPath: #keyPath(AVPlayer.currentItem.status), options:[.new, .initial], context: nil)

            let center = NotificationCenter.default
            center.addObserver(self, selector: Selector(("newErrorLogEntry:")), name: .AVPlayerItemNewErrorLogEntry, object: player!.currentItem)
            center.addObserver(self, selector: Selector(("failedToPlayToEndTime:")), name: .AVPlayerItemFailedToPlayToEndTime, object: player!.currentItem)
        }
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
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if let _: AVPlayer = object as? AVPlayer, keyPath == #keyPath(AVPlayer.currentItem.status) {
            
            let newStatus: AVPlayerItem.Status
            
            if let newStatusAsNumber = change?[NSKeyValueChangeKey.newKey] as? NSNumber {
                newStatus = AVPlayerItem.Status(rawValue: newStatusAsNumber.intValue)!
            } else {
                newStatus = .unknown
            }
            if newStatus == .failed {
                print("Error: \(String(describing: self.player?.currentItem?.error?.localizedDescription)), error: \(String(describing: self.player?.currentItem?.error))")
            }
        }
    }

    func newErrorLogEntry(_ notification: Notification) {
        guard let object = notification.object, let playerItem = object as? AVPlayerItem else {
            return
        }
        guard let errorLog: AVPlayerItemErrorLog = playerItem.errorLog() else {
            return
        }
        print("Error: \(errorLog)")
    }

    func failedToPlayToEndTime(_ notification: Notification) {
        let error = notification.userInfo!["AVPlayerItemFailedToPlayToEndTimeErrorKey"] as! Error
        print("Error: \(error.localizedDescription), error: \(error)")
    }
}

extension AppDelegate: DisplayDelegate {
    
    func screenGrabbed(_ ioSurface: IOSurfaceRef) {
        framesGrabbed += 1

        guard grabbedWindow.isVisible else { return }
        
        let ciImage = CIImage(ioSurface: ioSurface)
        let context = CIContext(options: nil)
        var cgImage = context.createCGImage(ciImage, from: ciImage.extent)!

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

extension AppDelegate: PlayerDelegate {
    func urlAvailable(_ url: URL) {
        print("\(url.absoluteString) is available")
        outputURL = url
    }
}
