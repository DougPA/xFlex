//
//  PanafallSplitView.swift
//  xFlex v0.5
//
//  Created by Douglas Adams on 6/10/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa

// --------------------------------------------------------------------------------
// MARK: - Panafall Button Split View class implementation
// --------------------------------------------------------------------------------

final class PanafallButtonSplitView: NSSplitView {
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties

    private var _buttonTracking: NSTrackingArea?
    private let _trackingOptions = NSTrackingAreaOptions.mouseEnteredAndExited.union(.activeInActiveApp)
    
    private let kButtonViewWidth: CGFloat = 75              // default button area width
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {
        
//        // make the button area colored & non-opaque
//        layer?.backgroundColor = _u.color(forType: .dbLegendBackground).cgColor
//        
//        layer?.opacity = 0.7
        
        // hide the Button area
//        buttonViewWidth.constant = 0
        
        // add a Tracking area
//        addTrackingArea()
    }
    
    deinit {
        
        // remove the Tracking area (if any)
        removeTrackingArea()

//        Swift.print( URL( fileURLWithPath: #file).lastPathComponent + ", " + #function)
    }

    /// Mouse entered the Button area
    ///
    /// - Parameter theEvent: mouse Event
    ///
    override func mouseEntered(with theEvent: NSEvent) {
        
        // make the Button View visible
        Swift.print("mouse Entered")
        
        
//        setPosition(kButtonViewWidth, ofDividerAt: 0)
    }
    
    /// Mouse exited the Button area
    ///
    /// - Parameter theEvent: mouse Event
    ///
    override func mouseExited(with theEvent: NSEvent) {
        
        // make the Button View invisible
        Swift.print("mouse Exited")

//        setPosition(0, ofDividerAt: 0)
    }
    /// Respond to updateTrackingAreas calls (automaticly called by the view)
    ///
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        removeTrackingArea()
        addTrackingArea()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Add a Tracking Area for the Button view
    ///
    public func addTrackingArea() {
        
        // create the tracking rectangle
        let rect = NSRect(x: 0, y: 0, width: kButtonViewWidth, height: frame.height)
        
        // create & add the Button View Tracking Area
        _buttonTracking = NSTrackingArea(rect: rect, options: _trackingOptions, owner: self, userInfo: ["Type": "button"])
        addTrackingArea(_buttonTracking!)
    }
    /// Remove the Tracking Area (if any) for the Button view
    ///
    private func removeTrackingArea() {
        
        // remove the existing Button View Tracking Area (if any)
        if _buttonTracking != nil { removeTrackingArea(_buttonTracking!) }
    }
    
}
