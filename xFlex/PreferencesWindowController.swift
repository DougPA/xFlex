//
//  PreferencesWindowController.swift
//  xFlex
//
//  Created by Douglas Adams on 3/20/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Foundation
import Cocoa

final class PreferencesWindowController: NSWindowController {
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        Swift.print("menuItem = \(menuItem)")
        
        return true
    }

    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
    
        Swift.print("prepare, \(String(describing: segue.identifier))")
    
    }
}
