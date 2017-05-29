//
//  ButtonViewController.swift
//  xFlex
//
//  Created by Douglas Adams on 1/17/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa

class ButtonViewController: NSViewController {

    private let kBandPopover = "BandPopover"
    private let kAntennaPopover = "AntennaPopover"
    private let kDisplayPopover = "DisplayPopover"
    private let kDaxPopover = "DaxPopover"

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        
        switch segue.identifier! {
            
        case kBandPopover, kAntennaPopover, kDisplayPopover, kDaxPopover:
            
            // pass the Popovers a reference to this controller
            (segue.destinationController as! NSViewController).representedObject = parent as! PanafallButtonViewController
            
        default:
            break
        }
    }
    
}
