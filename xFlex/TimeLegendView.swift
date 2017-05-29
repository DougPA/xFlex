//
//  TimeLegendView.swift
//  xFlex
//
//  Created by Douglas Adams on 12/27/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI

class TimeLegendView : NSView {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    override var flipped: Bool { return true }
    var font = NSFont( name: "Menlo-Bold", size: 12 )!
    
    var lineDuration: CGFloat = 40 {                // line duration in milliseconds
        didSet {
            if oldValue != lineDuration {
                dispatch_async(dispatch_get_main_queue()) { [unowned self] in
                    self.needsDisplay = true
                }}
        }
    }
    var spacing: CGFloat = 2                         // default time between marks (seconds)
    var spacings: [CGFloat] =                        // spacing choices
    [
        2, 4, 5, 10, 30
    ]
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _rightClick: NSClickGestureRecognizer!
    private let _kRightButton = 0x02

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {
        
        // setup Right Single Click recognizer
        _rightClick = NSClickGestureRecognizer(target: self, action: #selector(GridView.rightClick(_:)))
        _rightClick.buttonMask = _kRightButton
        _rightClick.numberOfClicksRequired = 1
        addGestureRecognizer(_rightClick)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden Drawing methods
    
    override func drawRect(dirtyRect: NSRect) {
        
        // set the Background color
        layer?.backgroundColor = NSColor.blackColor().CGColor
        layer?.opacity = 0.4
        
        // setup the legend font & color
        let attributes = [ NSForegroundColorAttributeName: NSColor.yellowColor(),  NSFontAttributeName: font]
        let height = "-00s".sizeWithAttributes(attributes).height
        
        // calculate parameters
        let heightInSeconds = (CGFloat(lineDuration) * frame.height) / 1_000
        let numberOfMarks = heightInSeconds / spacing
        let heightDelta = frame.height / numberOfMarks
        
        // if any of the marks are visible
        if heightDelta <= frame.height {

            // draw one legend mark per time increment
            for i in 1...Int(floor(numberOfMarks)) {
                let linePosition = (CGFloat(i) * heightDelta) - height
                // format & draw the legend
                let lineLabel = String(format: "-%ds", i * Int(spacing))
                lineLabel.drawAtPoint(NSMakePoint(0, linePosition) , withAttributes: attributes)
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal Mouse methods
    
    //
    // respond to Right Click gesture, show the popup
    //      called on the Main Queue
    //
    func rightClick(gestureRecognizer: NSClickGestureRecognizer) {
        var item: NSMenuItem!
        
        // create the popup menu
        let menu = NSMenu(title: "Spacings")
        
        // get the "click" coordinates and convert to this View
        let mouseLocation = gestureRecognizer.locationInView(self)
        
        // populate the popup menu
        for i in 0..<spacings.count {
            item = menu.insertItemWithTitle("\(spacings[i])s", action: #selector(TimeLegendView.contextMenu(_:)), keyEquivalent: "", atIndex: i)
            item.tag = Int(spacings[i])
            item.target = self
        }
        
        // display the popup
        menu.popUpMenuPositioningItem(menu.itemAtIndex(0), atLocation: mouseLocation, inView: self)
    }
    //
    // respond to the Context Menu selection
    //      called on the Main Queue
    //
    func contextMenu(sender: NSMenuItem) {
        
        
        Swift.print(sender.tag)
        
        spacing = CGFloat(sender.tag)
        needsDisplay = true
        
    }
}
