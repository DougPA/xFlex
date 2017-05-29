//
//  FilterView.swift
//  xFlex v0.5
//
//  Created by Douglas Adams on 12/8/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI

final class FilterView : NSView {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    var panadapter: Panadapter!               // Panadapter associated with this view
    
    weak var slice: xFlexAPI.Slice?         // Slice associated with this view
    var mouseIsDown = false
    var filterMaxWidth = 12_000             // maximum width of a filter
    
    var font = NSFont( name: "Menlo-Bold", size: 12 )!  // Filter legend font
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private var _start: CGFloat { get { return panadapter.center - (panadapter.bandwidth/2) }}
    private var _end: CGFloat { get { return panadapter.center + (panadapter.bandwidth/2) }}
    private var _hzPerUnit: CGFloat { get { return (_end - _start) / superview!.frame.width }}

    private let _u = UserDefaults.standard                  // Shared user defaults
    private var _path = NSBezierPath()
    private var _attributes: [String:AnyObject]!
    private var _label: String!
    private var _labelWidth: CGFloat!

    // mouse position
    private var _initialPosition: NSPoint?
    private var _previousPosition: NSPoint?
    private enum DragType { case right, left, center }
    private var _dragType: DragType?
    // tracking areas
    private var _rightTrackingArea: NSTrackingArea?
    private var _centerTrackingArea: NSTrackingArea?
    private var _leftTrackingArea: NSTrackingArea?
    private var _activeTrackingArea: NSTrackingArea?
    private let _trackingOptions = NSTrackingAreaOptions.mouseEnteredAndExited.union(.activeInActiveApp)
    
    private var _lowerLimit = 0
    private var _upperLimit = 0

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    override func awakeFromNib() {

        // hidden by default
        isHidden = true
    }
    
    deinit {
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden Drawing methods
    
    override func draw(_ dirtyRect: NSRect) {
        
        layer?.backgroundColor = _u.color(forType: .filterLegendBackground).cgColor
        
        // set the color
        _attributes = [ NSForegroundColorAttributeName: _u.color(forType: .filterLegend),  NSFontAttributeName: font]
        _u.color(forType: .filterLegend).set()
        
        _path.setLineDash( [2.0, 0.0], count: 2, phase: 0 )     // solid lines

        // create the filter shape based on the View width
        _path.move(to: NSPoint(x: 0, y: 0))
        _path.line(to: NSPoint(x: frame.width * 0.1, y: frame.height * 0.6))
        _path.line(to: NSPoint(x: frame.width * 0.9, y: frame.height * 0.6))
        _path.line(to: NSPoint(x: frame.width, y: 0))
        
        // draw the filter shape
        _path.strokeRemove()
        
        // create the dividers
        _path.setLineDash( [2.0, 1.0], count: 2, phase: 0 )     // dashed lines
        let divider1 = frame.width/3
        _path.vLine(at: divider1, fromY: frame.height * 0.7, toY: 0)
        _path.vLine(at: divider1 * 2, fromY: frame.height * 0.7, toY: 0)
        
        // draw the dividers
        _path.strokeRemove()
        
        // draw the filter params (if the Slice property has been populated)
        if let slice = slice {
            
            // mark the center
            let center = frame.width/2
            _path.vLine(at: center, fromY: frame.height * 0.7, toY: frame.height * 0.5)
            
            // net width label
            _label = String(format: "%d", -slice.filterLow + slice.filterHigh)
            _labelWidth = _label.size(withAttributes: _attributes).width
            _label.draw( at: NSMakePoint(center - _labelWidth/2, frame.height * 0.75), withAttributes: _attributes)
            
            // low width label
            _label = String(format: "%d", -slice.filterLow)
            _label.draw( at: NSMakePoint(frame.width * 0.1, frame.height * 0.2), withAttributes: _attributes)
            
            // high width label
            _label = String(format: "%d", slice.filterHigh)
            _labelWidth = _label.size(withAttributes: _attributes).width
            _label.draw(at: NSMakePoint(frame.width * 0.9 - _labelWidth, frame.height * 0.2), withAttributes: _attributes)
            
            // draw
            _path.strokeRemove()
        }
    }
    
    // ********** Filter Dragging **********
    
    //
    // Process a MouseDown / MouseUp / MouseExited / MouseDragged event
    //      called on the Main Queue
    //
    override func mouseDown(with theEvent: NSEvent) {
        
        // get the mouse position
        _previousPosition = theEvent.locationInWindow
        
        // get the mouse position relative to this View
        _initialPosition = convert(theEvent.locationInWindow, from: nil)
        mouseIsDown = true
        
        // decide which portion of the Filter we are dragging
        if _initialPosition!.x < frame.width/3 {
            
            _dragType = .left
        
        } else if _initialPosition!.x > 2 * (frame.width/3) {
            
            _dragType = .right
        
        } else {
            
            _dragType = .center
        }
        
        self.window?.invalidateCursorRects(for: self)
    }
    
    override func mouseUp(with theEvent: NSEvent) {
        
        mouseIsDown = false
        _dragType = nil
        self.window?.invalidateCursorRects(for: self)
    }
    
    override func mouseDragged(with theEvent: NSEvent) {
        var newLow = 0
        var newHigh = 0
        
        // get the mouse position
        let currentPosition = theEvent.locationInWindow
        
        // calculate the offset from the previous position
        let offsetX = currentPosition.x - _previousPosition!.x
        let offsetY = currentPosition.y - _previousPosition!.y
        
        // dragging right, left or center?
        switch _dragType! {
        case .left:
            
            // adjust Filter Low value
            newLow = slice!.filterLow + Int(offsetX * _hzPerUnit)
            newHigh = slice!.filterHigh
            
        case .center:
            
            // dragging Up/Down or Left/Right ?
            if abs(offsetY) > 0 {
                // Up/Down, update its Width
                newLow = slice!.filterLow - Int((offsetY * _hzPerUnit))
                newHigh = slice!.filterHigh + Int((offsetY * _hzPerUnit))
            } else {
                // Left/Right, update its Frequency
                newLow = slice!.filterLow + Int((offsetX * _hzPerUnit))
                newHigh = slice!.filterHigh + Int((offsetX * _hzPerUnit))
            }
        case .right:
            
            // adjust Filter High value
            newLow = slice!.filterLow
            newHigh = slice!.filterHigh + Int(offsetX * _hzPerUnit)
        }
        
        // based on Mode, enforce limitations on Filter bounds
        switch slice!.mode {
        case SliceMode.am.rawValue, SliceMode.sam.rawValue, SliceMode.fm.rawValue, SliceMode.dfm.rawValue, SliceMode.nfm.rawValue:
            
            slice!.filterLow = bracket( newLow, min: -12_000, max: 0)
            slice!.filterHigh = bracket( newHigh, min: 0, max: 12_000)
        
        case SliceMode.cw.rawValue:
            
            slice!.filterLow = min( newLow, 12_000)
            slice!.filterHigh = max( newHigh, 12_000)
            
        case SliceMode.usb.rawValue, SliceMode.digu.rawValue:
            
            slice!.filterLow = bracket( newLow, min: 0, max: 12_000)
            slice!.filterHigh = bracket( newHigh, min: 0, max: 12_000)
            
        case SliceMode.lsb.rawValue, SliceMode.digl.rawValue:
            
            slice!.filterLow = bracket( newLow, min: -12_000, max: 0)
            slice!.filterHigh = bracket( newHigh, min: -12_000, max: 0)
        
        default:
            break
        }

        needsDisplay = true
        
        // reset the _previousPosition (to allow offset calculation next time through)
        _previousPosition = currentPosition
    }
    //
    // Respond to resetCursorRects calls (automaticly called by the view)
    //      called on the Main Queue
    //
    override func resetCursorRects() {
        
        super.resetCursorRects()
        
        if mouseIsDown {
            switch _dragType! {
            
            case .left, .right:
                addCursorRect(bounds, cursor: NSCursor.resizeLeftRight())
            
            case .center:
                // FIXME: need a different cursor
                addCursorRect(bounds, cursor: NSCursor.resizeLeftRight())
            }
        }
    }
    //
    // Force a value to be within a Min/Max range
    //
    func bracket<T: Comparable>( _ value: T, min: T, max: T) -> T {
        var returnValue = value
        
        if returnValue < min { returnValue = min }
        
        if returnValue > max { returnValue = max }
        
        return returnValue
    }
}

