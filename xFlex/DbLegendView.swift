//
//  DbLegendView.swift
//  StackPlay
//
//  Created by Douglas Adams on 11/12/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI

final class DbLegendView : NSView {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var panafall: Panafall!                     // Panafall associated with this view
    var font = NSFont( name: "Menlo-Bold", size: 12 )!  // DbLegend font
    var format = " %4.0f"                               // DbLegend format
    var dragThreshold: CGFloat = 10
    
    var spacing = 10                                    // default Dbm between marks
    var spacings =                                      // spacing choices
    [
        5, 10, 15, 20, 25, 30, 50
    ]
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _p = ViewPreferences.sharedInstance          // View Preferences

    private var _start: CGFloat { get { return panafall.center - (panafall.bandwidth/2) }}
    private var _end: CGFloat { get { return panafall.center + (panafall.bandwidth/2) }}
    private var _hzPerUnit: CGFloat { get { return (_end - _start) / self.frame.width }}
    // mouse position
    private var _mouseIsDown = false
    private var _initialPosition: NSPoint?
    private var _previousPosition: NSPoint?
    // tracking areas
    private var _topTrackingArea: NSTrackingArea?
    private var _bottomTrackingArea: NSTrackingArea?
    private var _activeTrackingArea: NSTrackingArea?
    private let _trackingOptions = NSTrackingAreaOptions.MouseEnteredAndExited.union(.ActiveInActiveApp)
//    // gestures
//    private var _rightClick: NSClickGestureRecognizer!
//    private let _kRightButton = 0x02

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {
        
        // use the default line spacing
        spacing = Int(_p.dbLineSpacing)
        
//        // setup Right Single Click recognizer
//        _rightClick = NSClickGestureRecognizer(target: self, action: #selector(GridView.rightClick(_:)))
//        _rightClick.buttonMask = _kRightButton
//        _rightClick.numberOfClicksRequired = 1
//        addGestureRecognizer(_rightClick)

        addTrackingAreas()
    }
    
    deinit {

        removeTrackingAreas()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden Drawing methods
    
    override func drawRect(dirtyRect: NSRect) {
        
        // set the Background color
        layer?.backgroundColor = _p.dbBackground.CGColor
        layer?.opacity = 0.5
        
        let attributes = [ NSForegroundColorAttributeName: _p.dbLegend,  NSFontAttributeName: font]
        let height = "-000".sizeWithAttributes(attributes).height
        
        // calculate the spacings
        let dbRange = panafall.maxDbm - panafall.minDbm
        let yIncrPerDb = dirtyRect.height / dbRange
        let yIncrPerMark = yIncrPerDb * CGFloat(spacing)
        
        // calculate the number & position of the legend marks
        let numberOfMarks = Int( dbRange / CGFloat(spacing))
        let firstMarkValue = panafall.minDbm - (panafall.minDbm % CGFloat(spacing))
        let firstMarkPosition = (-panafall.minDbm % CGFloat(spacing)) * yIncrPerDb
        
        // draw the legend
        for i in 0...numberOfMarks {
            
            // calculate the position of the legend
            let linePosition = firstMarkPosition + (CGFloat(i) * yIncrPerMark) - height/3
            
            // format & draw the legend
            let lineLabel = String(format: format, firstMarkValue + (CGFloat(i) * CGFloat(spacing)))
            lineLabel.drawAtPoint( NSMakePoint(0, linePosition ) , withAttributes: attributes)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden Mouse methods
    
    // ********** Dbm level Dragging **********
    
    //
    // Process a MouseDown / MouseUp / MouseEntered / MouseExited / MouseDragged event
    //      called on the Main Queue
    //
    override func mouseDown(theEvent: NSEvent) {
        
        _previousPosition = convertPoint(theEvent.locationInWindow, fromView: nil)
        _initialPosition = _previousPosition
        _mouseIsDown = true
        
        self.window?.invalidateCursorRectsForView(self)
    }
    
    override func mouseUp(theEvent: NSEvent) {

        _mouseIsDown = false
        
        self.window?.invalidateCursorRectsForView(self)
    }

    override func mouseEntered(theEvent: NSEvent) {
        
        if !_mouseIsDown {
            
            _activeTrackingArea = theEvent.trackingArea
            
            self.window?.invalidateCursorRectsForView(self)
        }
    }

    override func mouseExited(theEvent: NSEvent) {
        
        if !_mouseIsDown {
            
            _activeTrackingArea = nil
        }
    }
    
    override func mouseDragged(theEvent: NSEvent) {
        
        // YES, get the mouse position (relative to this View)
        let currentPosition = self.convertPoint(theEvent.locationInWindow, fromView: nil)
        
        // calculate the offset from the previous position
        var offsetY = currentPosition.y - _previousPosition!.y

        // is the Option/Alt key depressed?
        if theEvent.modifierFlags.contains(.AlternateKeyMask) {
            
            // YES, drag continuously
            // Top or Bottom half?
            if _activeTrackingArea == _topTrackingArea {
                
                panafall.maxDbm = panafall.maxDbm - offsetY
            
            } else if _activeTrackingArea == _bottomTrackingArea {
                
                panafall.minDbm = panafall.minDbm - offsetY
            }
            
            // force a redraw of the DbLegend & the Grid Views
            needsDisplay = true
            (superview as! PanadapterView).gridView.needsDisplay = true
            
            // reset the _previousPosition (to allow offset calculation next time through)
            _previousPosition = currentPosition

        } else {
            
            // NO, have we exceeded the dragThreshold?
            if abs(offsetY) > dragThreshold {
                
                // YES, incr by the Line Spacing value
                offsetY = (offsetY > 0 ? _p.dbLineSpacing : -_p.dbLineSpacing)
                
                // Top or Bottom half?
                if _activeTrackingArea == _topTrackingArea {
                    
                    panafall.maxDbm = panafall.maxDbm - offsetY
                
                } else if _activeTrackingArea == _bottomTrackingArea {
                    
                    panafall.minDbm = panafall.minDbm - offsetY
                }
                
                // force a redraw of the DbLegend & the Grid Views
                needsDisplay = true
                (superview as! PanadapterView).gridView.needsDisplay = true
                
                // reset the _previousPosition (to allow offset calculation next time through)
                _previousPosition = currentPosition
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
            item = menu.insertItemWithTitle("\(spacings[i]) dbm", action: #selector(DbLegendView.contextMenu(_:)), keyEquivalent: "", atIndex: i)
            item.tag = spacings[i]
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
        
        spacing = sender.tag
        needsDisplay = true
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden Tracking Area methods
    
    //
    // Respond to updateTrackingAreas calls (automaticly called by the view)
    //      called on the Main Queue
    //
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        removeTrackingAreas()
        addTrackingAreas()
    }
    //
    // Respond to resetCursorRects calls (automaticly called by the view)
    //      called on the Main Queue
    //
    override func resetCursorRects() {
        
        if _mouseIsDown {
            let aCursor = NSCursor.resizeUpDownCursor()
            
            self.addCursorRect(_topTrackingArea!.rect, cursor: aCursor)
            aCursor.setOnMouseEntered(true)

            self.addCursorRect(_bottomTrackingArea!.rect, cursor: aCursor)
            aCursor.setOnMouseEntered(true)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Tracking Area methods
    
    //
    //      setup/remove Top/Bottom tracking areas
    //      called on the Main Queue
    //
    private func addTrackingAreas() {
        
        // create the Bottom tracking rectangle
        let rectBottom = NSRect(x: 0, y: 0, width: frame.width, height: frame.size.height/2)
        
        // create & add the Bottom Tracking Area
        _bottomTrackingArea = NSTrackingArea(rect: rectBottom, options: _trackingOptions, owner: self, userInfo: nil)
        addTrackingArea(_bottomTrackingArea!)

        // create the Top tracking rectangle
        let rectTop = NSRect(x: 0, y: frame.size.height/2, width: frame.width, height: frame.size.height/2)
        
        // create & add the Top Tracking Area
        _topTrackingArea = NSTrackingArea(rect: rectTop, options: _trackingOptions, owner: self, userInfo: nil)
        addTrackingArea(_topTrackingArea!)
}
    
    private func removeTrackingAreas() {
        
        // remove the existing Tracking Areas (if any)
        if _bottomTrackingArea != nil { removeTrackingArea(_bottomTrackingArea!) }
        if _topTrackingArea != nil { removeTrackingArea(_topTrackingArea!) }
    }

}
