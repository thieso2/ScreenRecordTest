//
//  File.swift
//  VideoSender
//
//  Created by James Wilson on 7/31/17.
//  Copyright © 2017 jimdanger. All rights reserved.
//

import Foundation
import AVFoundation
import AVKit


class DisplayLayer: NSView {
    var aVSampleBufferDisplay = AVSampleBufferDisplayLayer()
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)!
        wantsLayer = true
        layer!.addSublayer(aVSampleBufferDisplay)
        aVSampleBufferDisplay.frame = layer!.bounds
    }
    
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        aVSampleBufferDisplay.frame.size = bounds.size
        CATransaction.commit()
    }
    
    func enqueue(cMSamplebuffer: CMSampleBuffer){
        aVSampleBufferDisplay.enqueue(cMSamplebuffer)
    }
}
