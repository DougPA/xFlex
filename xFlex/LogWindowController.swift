//
//  LogWindowController.swift
//  xFlex v0.2
//
//  Created by Douglas Adams on 9/6/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

// --------------------------------------------------------------------------------
// FIXME: - This is only needed due to a bug in Window FrameAutoSave behavior
// --------------------------------------------------------------------------------

import Cocoa

final class LogWindowController : NSWindowController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {
        
        // FIXME: This only works if it is different from the value in IB
        windowFrameAutosaveName = "LogWindow"
    }
}
