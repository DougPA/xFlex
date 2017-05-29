//
//  RadioWindowController.swift
//  xFlex v0.2
//
//  Created by Douglas Adams on 10/17/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

// --------------------------------------------------------------------------------
// FIXME: - This is only needed due to a bug in Window FrameAutoSave behavior
// --------------------------------------------------------------------------------

import Cocoa

final class RadioWindowController : NSWindowController {

    @IBOutlet fileprivate weak var markersButton: NSButton!
    @IBOutlet fileprivate weak var sideButton: NSButton!

    fileprivate var _p = ViewPreferences.sharedInstance             // shared Preferences

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {
        
        // FIXME: This only works if it is different from the value in IB
//        windowFrameAutosaveName = "RadioWindow"
        
        markersButton.state = (_p.showMarkers ? NSOnState : NSOffState)
//        sideButton.state = (_p.sideViewOpen ? NSOnState : NSOffState)
    }
    
}

