//
//  AppDelegate.swift
//  grab
//
//  Created by Thies C. Arntzen on 22.10.18.
//  Copyright © 2018 tmp8. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    @IBOutlet weak var liveImage: NSImageView!
    
    var grab = Grab()
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        grab.run { (image) in
            DispatchQueue.main.async {
                self.liveImage.image = image
                self.liveImage.needsDisplay = true
            }
        }
    }
}

