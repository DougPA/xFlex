//
//  SliceView.swift
//  xFlex v0.5
//
//  Created by Douglas Adams on 11/14/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import xFlexAPI
import Cocoa

// --------------------------------------------------------------------------------
// MARK: - Slice View class implementation
// --------------------------------------------------------------------------------

final class SliceView : NSView {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties

    var panadapter: Panadapter? {                       // Panafall associated with this view
        didSet {

            // pass the reference to the subview(s)
//            _buttonView.panafall = panafall!
            _filterView.panadapter = panadapter!

            // begin observing Notifications
            addNotifications()

            // track entry/exit from the buttonView area
            addButtonViewTrackingArea()
        }
    }
    var waterfall: Waterfall! {                     // Waterfall associated with this view
        didSet {

            // pass the reference to the subview(s)
//            _buttonView.waterfall = waterfall
        }
    }
    
    var frequencyLineWidth: CGFloat = 1.0
    var tnfMinWidth: CGFloat = 25                   // minimum width of a TNF
    var tnfMaxWidth: CGFloat = 5000                 // maximum width of a TNF
    var tnfWidthIncrement: CGFloat = 10             // width incr of a TNF
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet private var _buttonView: NSView!
    @IBOutlet private var _buttonViewWidth: NSLayoutConstraint!
    
    @IBOutlet private var _filterView: FilterView!
    @IBOutlet private var _filterViewPosition: NSLayoutConstraint!
    @IBOutlet private var _filterViewWidth: NSLayoutConstraint!
    @IBOutlet private var _filterViewHeight: NSLayoutConstraint!
    
    private var _start: CGFloat { get { return panadapter!.center - (panadapter!.bandwidth/2) }}
    private var _end: CGFloat { get { return panadapter!.center + (panadapter!.bandwidth/2) }}
    private var _hzPerUnit: CGFloat { get { return (_end - _start) / self.frame.width }}

    private let kModule = "SliceView"                           // Module Name reported in log messages
    private let _u = UserDefaults.standard                      // Shared user defaults
    private let _log = Log.sharedInstance                       // Shared log
    private lazy var _path = NSBezierPath()

    // mouse position
    private var _mouseIsDown = false
    private var _initialPosition: NSPoint?
    private var _previousPosition: NSPoint?
    private enum DragDirection { case right, left, center }
    private var _filterDrag: DragDirection?

    // notification subscriptions
    private var _notifications = [NSObjectProtocol]()

    // keyPath property observations
    private let _sliceKeyPaths =                                // Slice keypaths to observe
        [
            "active",
            "frequency",
            "filterHigh",
            "filterLow"
        ]
    private let _tnfKeyPaths =                                  // Tnf keypaths to observe
        [
            #keyPath(Tnf.depth),
            #keyPath(Tnf.frequency),
            #keyPath(Tnf.permanent),
            #keyPath(Tnf.width)
        ]
    private var _sliceContext = 1
    private var _tnfContext = 2

    // tracking areas
    private var _sliceTracking = [SliceId: NSTrackingArea]()
    private var _filterTracking = [SliceId: NSTrackingArea]()
    private var _tnfTracking = [TnfId: NSTrackingArea]()
    private var _buttonTracking: NSTrackingArea?
    private let _trackingOptions = NSTrackingAreaOptions.mouseEnteredAndExited.union(.activeInActiveApp)
    private var _activeTrackingArea: NSTrackingArea?
    
    
    private let _kButtonViewWidth: CGFloat = 75
    private let _kFilterViewWidth: CGFloat = 150
    private let _kFilterViewHeight: CGFloat = 50

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods

    override func awakeFromNib() {

        _buttonView.isHidden = true
    }
    
    deinit {

        removeButtonViewTrackingArea()
    }
    //
    // Respond to changes in observed KeyPaths
    //      may be called on any thread
    //
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        // interact with the UI
        DispatchQueue.main.async { [unowned self] in
            
            if context == &self._sliceContext {
                let slice = object as! xFlexAPI.Slice
                
                if self._filterView != nil {
                    
                    // position the Filter View
                    self.positionFilterView(slice)
                }
            }
            
            // force a redraw
            self.needsDisplay = true
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden Drawing methods
    
    //
    // Draw the Filters, Tnf's and Frequency lines
    //
    override func draw(_ dirtyRect: NSRect) {
        
        // get a list of Slices on this Panadapter
        let sliceArray = panadapter!.radio!.findSlicesOn(panadapter!.id)

        // draw Filter Outlines (active & inactive Slices)
        drawFilterOutlines(sliceArray)
        
        // draw Tnf outlines
        drawTnfOutlines()
        
        // draw Frequency lines (active & inactive Slices)
        drawFrequencyLines(sliceArray)
        
//        // draw band markers (if enabled)
//        if _p.showMarkers { drawMarkers() }
        
        // update cursor rects
        self.window?.invalidateCursorRects(for: self)
        _filterView.needsDisplay = true
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden Cursor/Mouse methods
    
    //
    // respond to the Scroll Wheel
    //      called on the Main Queue
    //
    override func scrollWheel(with theEvent: NSEvent) {
        
        // ignore events not in the Y direction
        if theEvent.deltaY != 0 {
            
            // Increase or Decrease?
            let isUp = theEvent.deltaY > 0 ? true : false
            
            // find the Active Slice
            if let slice = panadapter!.radio!.findActiveSliceOn(panadapter!.id) {
                
                // calculate how close the Slice should come to the edge of the Panadapter
                let edgeBuffer = panadapter!.bandwidth / 10

                // Moving the frequency higher?
                if isUp {
                    
                    // moving higher, calculate the end & the distance to it
                    let end = (panadapter!.center + panadapter!.bandwidth/2)
                    let delta = end - slice.frequency
                    
                    // is the Slice too close to the end?
                    if delta <= edgeBuffer {
                        
                        // YES, adjust the panafall center frequency
                        panadapter!.center = panadapter!.center + CGFloat(slice.step)
                        
                    } else {
                        
                        // NO, adjust the slice frequency
                        slice.frequency = slice.frequency + CGFloat(slice.step)
                    }
                } else {
                
                    // moving lower, calculate the Start & the distance to it
                    let start = (panadapter!.center - panadapter!.bandwidth/2)
                    let delta = slice.frequency - start
                    
                    // is the Slice too close to the start?
                    if delta <= edgeBuffer {
                        
                        // YES, adjust the panafall center frequency
                        panadapter!.center = panadapter!.center - CGFloat(slice.step)
                    
                    } else {
                        
                        // NO, adjust the slice frequency
                        slice.frequency = slice.frequency - CGFloat(slice.step)
                    }
                }
            }
        }
    }
    
    // ********** Slice / Tnf Dragging **********
    
    //
    // Process a MouseDown / MouseUp / MouseEntered / MouseExited / MouseDragged event
    //      called on the Main Queue
    //
    override func mouseDown(with theEvent: NSEvent) {
        
        _previousPosition = convert(theEvent.locationInWindow, from: nil)
        _initialPosition = _previousPosition
        _mouseIsDown = true
        
        self.window?.invalidateCursorRects(for: self)
        super.mouseDown(with: theEvent)
    }

    override func mouseUp(with theEvent: NSEvent) {
        _mouseIsDown = false
        _filterDrag = nil
        
        self.window?.invalidateCursorRects(for: self)
    }

    override func mouseEntered(with theEvent: NSEvent) {

        if !_mouseIsDown {
            _activeTrackingArea = theEvent.trackingArea

            switch theEvent.trackingArea!.userInfo!["Type"] as! String {
            
            case "button":
                // make the Button View visible
                _buttonView.isHidden = false
                
            case "filter":
                // get the slice
                let slice = theEvent.trackingArea!.userInfo!["Object"] as! xFlexAPI.Slice
                _filterView.slice = slice
                
                // position the Filter View
                positionFilterView(slice)

                // make the Filter View visible
                _filterView.isHidden = false
            
            default:
                break
            }
        }
    }

    override func mouseExited(with theEvent: NSEvent) {

        if !_mouseIsDown {
            _activeTrackingArea = nil

            switch theEvent.trackingArea!.userInfo!["Type"] as! String {
            case "button":
                // make the Button View invisible
                _buttonView.isHidden = true
                
            case "filter":
                // make the Filter View invisible
                if !_filterView.mouseIsDown { _filterView.isHidden = true }
                
            default:
                break
            }
        }
    }

    override func mouseDragged(with theEvent: NSEvent) {
        
        // get the mouse position (relative to this View)
        let currentPosition = self.convert(theEvent.locationInWindow, from: nil)

        // calculate the offset from the previous position
        let offsetX = currentPosition.x - _previousPosition!.x
        var offsetY = currentPosition.y - _previousPosition!.y
        
        // are we dragging an Object?
        if _activeTrackingArea != nil {

            // YES, identify the Object
            if let tnf = _activeTrackingArea!.userInfo!["Object"] as? Tnf {
                // Object is a Tnf
                
                offsetY = CGFloat(Int(offsetY))
                // dragging Up/Down or Left/Right ?
                if abs(offsetY) > 0 {
                    
                    // Up/Down, update its Width (ignore small Y offsets)
                    tnf.width = (tnf.width + (offsetY * tnfWidthIncrement))
                
                } else {
                    
                    // Left/Right, update its Frequency
                    tnf.frequency = tnf.frequency + (offsetX * _hzPerUnit)
                }
                
            } else if let slice = _activeTrackingArea!.userInfo!["Object"] as? xFlexAPI.Slice {
                // Object is a Slice
                
                // --- Slice ---, update its Frequency
                slice.frequency = slice.frequency + (offsetX * _hzPerUnit)
            }
        
        } else {
            
            // NO, move the entire display
            panadapter!.center = panadapter!.center - (offsetX * _hzPerUnit)
        }
        needsDisplay = true
        
        // reset the _previousPosition (to allow offset calculation next time through)
        _previousPosition = currentPosition
    }
    //
    // Respond to updateTrackingAreas calls (automaticly called by the view)
    //      called on the Main Queue
    //
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        let sliceArray = panadapter!.radio!.findSlicesOn(panadapter!.id)
        for slice in sliceArray {
            removeSliceTrackingArea(slice)
            addSliceTrackingArea(slice)
        }
        
        let tnfsCopy = panadapter!.radio!.findAllTnfs()
        for (_, tnf) in tnfsCopy {
            removeTnfTrackingArea(tnf)
            addTnfTrackingArea(tnf)
        }
        
        removeButtonViewTrackingArea()
        addButtonViewTrackingArea()
    }
    //
    // Respond to resetCursorRects calls (automaticly called by the view)
    //      called on the Main Queue
    //
    override func resetCursorRects() {
        var aCursor: NSCursor
        
        if _mouseIsDown {
            
            aCursor = NSCursor.resizeLeftRight()
            
            // FIXME: need a 4-pointed cursor for Tnf
            
            // cursors over the Tnf's
            for (_, trackingArea) in _tnfTracking {
                self.addCursorRect(trackingArea.rect, cursor: aCursor)
                aCursor.setOnMouseEntered(true)
            }
            
            // cursors over the Slices
            for (_, trackingArea) in _sliceTracking {
                self.addCursorRect(trackingArea.rect, cursor: aCursor)
                aCursor.setOnMouseEntered(true)
            }
            
            // cursor when the entire frame is dragged
            if _activeTrackingArea == nil {
                
                let rect = NSRect(x: 50, y: 0, width: frame.width, height: frame.height)
                self.addCursorRect(rect, cursor: aCursor)
                aCursor.setOnMouseEntered(true)
            }
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    //
    // Remove this View and its sub views
    //
    func remove() {
        
        // release each view
        _buttonView = nil
        _filterView = nil
    }
    
    func redraw() {
        
        // interact with the UI
        DispatchQueue.main.async { [unowned self] in
            
            self.needsDisplay = true
            
            self._filterView.needsDisplay = true
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Drawing methods
    
    private func drawFilterOutlines(_ sliceArray: [xFlexAPI.Slice]) {

        for _slice in sliceArray {
            
            removeSliceTrackingArea(_slice)
            
            // calculate the Filter position & width
            let _filterPosition = (((CGFloat(_slice.filterLow) + _slice.frequency) - _start) / _hzPerUnit)
            let _filterWidth = CGFloat(_slice.filterHigh - _slice.filterLow) / _hzPerUnit
            
            // draw the Filter
            let _rect = NSRect(x: _filterPosition, y: 0, width: _filterWidth, height: frame.size.height)
            _path.fillRect( _rect, withColor: _u.color(forType: .sliceFilter), andAlpha: CGFloat(_u.float(forType: .sliceFilterOpacity)!))
        }
        _path.strokeRemove()
        
    }
    
    private func drawTnfOutlines() {

        let tnfsCopy = panadapter!.radio!.findAllTnfs()
        for (_, _tnf) in tnfsCopy {
            
            // remove any existing Tracking Area
            removeTnfTrackingArea(_tnf)
            
            // calculate the Tnf position & width
            let _tnfPosition = ((_tnf.frequency - _tnf.width/2)  - _start) / _hzPerUnit
            let _tnfWidth = _tnf.width / _hzPerUnit
            
            let _color = panadapter!.radio!.tnfEnabled ? _u.color(forType: .tnfActive) : _u.color(forType: .tnfInactive)
            
            // draw the Tnf
            let _rect = NSRect(x: _tnfPosition, y: 0, width: _tnfWidth, height: frame.size.height)
            _path.fillRect( _rect, withColor: _color, andAlpha: CGFloat(_u.float(forType: .sliceFilterOpacity)!))
            _path.crosshatch(_rect, color: NSColor.white, depth: _tnf.depth)
            
            // install a new Tracking Area
            addTnfTrackingArea(_tnf)
        }
        _path.strokeRemove()
    }

    private func drawFrequencyLines(_ sliceArray: [xFlexAPI.Slice]) {
        // set the width & color
        _path.lineWidth = frequencyLineWidth
        _u.color(forType: .sliceInactive).set()
        
        // ********** Inactive Frequency Lines **********
        
        let inactiveSlices = sliceArray.filter {$0.active == false}
        for _slice in inactiveSlices {
            
            // calculate the position
            let _freqPosition = ((_slice.frequency - _start) / _hzPerUnit)
            
            // create the Frequency line
            _path.move(to: NSPoint(x: _freqPosition, y: frame.height))
            _path.line(to: NSPoint(x: _freqPosition, y: 0))
            
            // install the tracking area
            addSliceTrackingArea(_slice)
        }
        _path.strokeRemove()
        
        // ********** Active Frequency Lines **********
        
        // set the width & color
        _path.lineWidth = frequencyLineWidth
        _u.color(forType: .sliceActive).set()
        
        let activeSlices = sliceArray.filter {$0.active == true}
        for _slice in activeSlices {
            
            // calculate the position
            let _freqPosition = ((_slice.frequency - _start) / _hzPerUnit)
            
            // create the Frequency line
            _path.move(to: NSPoint(x: _freqPosition, y: frame.height))
            _path.line(to: NSPoint(x: _freqPosition, y: 0))
            
            // add the "active" Tag
            _path.drawTriangle(at: _freqPosition, topWidth: 15, triangleHeight: 15, topPosition: frame.size.height)
            
            // install the tracking area
            addSliceTrackingArea(_slice)
        }
        _path.strokeRemove()
    }
    
    
    
    
    
    
    
    
    
    
    
    // ----------------------------------------------------------------------------
    // MARK: - Private Tracking Area methods
    
    //
    //      setup/remove Slice/Tnf/Side/Filter tracking areas
    //      called on the Main Queue
    //
    private func addSliceTrackingArea(_ slice: xFlexAPI.Slice) {
        
        // make the tracking area wider if it would be too small to easily click on
        let actualWidth = CGFloat(slice.filterHigh - slice.filterLow)
        let filterWidth = max(panadapter!.bandwidth / 20, actualWidth)

        let trackingFilterLow = filterWidth == actualWidth ? CGFloat(slice.filterLow) : CGFloat(slice.filterLow) - (filterWidth - actualWidth)/2
        let trackingWidth = filterWidth / _hzPerUnit
        
        // calculate the Tracking Area position
        let trackingPosition = (trackingFilterLow + slice.frequency - _start) / _hzPerUnit
        
        // create the Filter rectangle (reserve bottom 50 for FilterView tracking area)
        let rect = NSRect(x: trackingPosition, y: 50, width: trackingWidth, height: frame.size.height - 50)

        // create & add the Slice Tracking Area
        _sliceTracking[slice.id] = NSTrackingArea(rect: rect, options: _trackingOptions, owner: self, userInfo: ["Type": "slice", "Object": slice])
        addTrackingArea(_sliceTracking[slice.id]!)
        
        // calculate the Frequency position
        let frequencyPosition = (slice.frequency - _start) / _hzPerUnit
        addFilterTrackingArea(frequencyPosition, width: Int(actualWidth), slice: slice)
    }
    
    private func removeSliceTrackingArea( _ slice: xFlexAPI.Slice) {
        
        removeFilterTrackingArea(slice)
        
        // remove the existing Slice Tracking Areas (if any)
        if _sliceTracking[slice.id] != nil {
            removeTrackingArea(_sliceTracking[slice.id]!)
            _sliceTracking[slice.id] = nil
        }
    }
    
    private func addTnfTrackingArea(_ tnf: Tnf) {

        // make the tracking area wider if it would be too small to easily click on
        let tnfWidth = (tnf.width < 500 ? 500 : tnf.width)
        let trackingWidth  = tnfWidth / _hzPerUnit

        // calculate the Tracking Area position
        let trackingPosition = ((tnf.frequency - tnfWidth/2)  - _start) / _hzPerUnit

        // create the Tnf rectangle
        let rect = NSRect(x: trackingPosition, y: 0, width: trackingWidth, height: frame.size.height)
        
        // create & add the Tnf Tracking Area
        _tnfTracking[tnf.id] = NSTrackingArea(rect: rect, options: _trackingOptions, owner: self, userInfo: ["Type": "tnf", "Object": tnf])
        addTrackingArea(_tnfTracking[tnf.id]!)
    }
    
    private func removeTnfTrackingArea(_ tnf: Tnf) {
        
        // remove the existing Tnf Tracking Area (if any)
        if _tnfTracking[tnf.id] != nil {
            
            removeTrackingArea(_tnfTracking[tnf.id]!)
            _tnfTracking[tnf.id] = nil
        }
    }

    private func addButtonViewTrackingArea() {
        
        // create the tracking rectangle
        let rect = NSRect(x: 0, y: 0, width: _kButtonViewWidth + 5, height: frame.size.height)
        
        // create & add the Button View Tracking Area
        _buttonTracking = NSTrackingArea(rect: rect, options: _trackingOptions, owner: self, userInfo: ["Type": "button"])
        addTrackingArea(_buttonTracking!)
    }

    private func removeButtonViewTrackingArea() {
        
        // remove the existing Button View Tracking Area (if any)
        if _buttonTracking != nil { removeTrackingArea(_buttonTracking!) }
    }

    private func addFilterTrackingArea(_ position: CGFloat, width: Int, slice: xFlexAPI.Slice) {

        // create the tracking rectangle
        let rect = NSRect(x: position - (_kFilterViewWidth/2), y: 0, width: _kFilterViewWidth, height: _kFilterViewHeight)
        
        // create & add the Filter Tracking Area
        _filterTracking[slice.id] = NSTrackingArea(rect: rect, options: _trackingOptions, owner: self, userInfo: ["Type": "filter", "Object": slice])
        addTrackingArea(_filterTracking[slice.id]!)
    }
    
    private func removeFilterTrackingArea(_ slice: xFlexAPI.Slice) {
        
        // remove the existing Filter Tracking Area (if any)
        if _filterTracking[slice.id] != nil {
            
            removeTrackingArea(_filterTracking[slice.id]!)
            _filterTracking[slice.id] = nil
        }
    }
    //
    // Position the Filter View using its constraints
    //
    private func positionFilterView(_ slice: xFlexAPI.Slice) {
        
        // set the constraints for the Width, Position & Height of the Filter View
        _filterViewWidth.constant = _kFilterViewWidth
        
        // height is fixed
        _filterViewHeight.constant = _kFilterViewHeight
        
        // center it on the slice frequency
        _filterViewPosition.constant = ((slice.frequency - _start) / _hzPerUnit) - (_kFilterViewWidth / 2)
        
        _filterView.needsDisplay = true
        
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subscriptions to Notifications
    ///
    private func addNotifications() {

        // Slice created
        NotificationCenter.default.addObserver(self, selector: #selector(sliceCreated(_:)),
                                               name: NSNotification.Name(rawValue: NotificationType.sliceInitialized.rawValue),
                                               object: nil)
        // Slice removed
        NotificationCenter.default.addObserver(self, selector: #selector(sliceRemoved(_:)),
                                               name: NSNotification.Name(rawValue: NotificationType.sliceShouldBeRemoved.rawValue),
                                               object: nil)
        // Tnf created
        NotificationCenter.default.addObserver(self, selector: #selector(tnfCreated(_:)),
                                               name: NSNotification.Name(rawValue: NotificationType.tnfInitialized.rawValue),
                                               object: nil)
        // Tnf removed
        NotificationCenter.default.addObserver(self, selector: #selector(tnfRemoved(_:)),
                                               name: NSNotification.Name(rawValue: NotificationType.tnfShouldBeRemoved.rawValue),
                                               object: nil)
        // User defaults changed
        NotificationCenter.default.addObserver(self, selector: #selector(defaultsChanged(_:)),
                                               name: UserDefaults.didChangeNotification,
                                               object: nil)
    }
    /// Process .sliceInitialized Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc private func sliceCreated(_ note: Notification) {

        // does the Notification contain a Slice object?
        if let slice = note.object as? xFlexAPI.Slice {
            
            // is it for this Panafall?
            if slice.panadapterId == self.panadapter!.id {
                
                // YES, log the event
                self._log.entry("Slice Initialized, ID = \(slice.id)", level: .debug, source: self.kModule)
                
                // add Slice property observers to the Slice being added
                for keyPath in self._sliceKeyPaths {
                    
                    slice.addObserver(self, forKeyPath: keyPath, options: .new, context: &self._sliceContext)
                }
                // force a redraw
                self.redraw()
            }
        }
    }
    /// Process .sliceWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc private func sliceRemoved(_ note: Notification) {

        // does the Notification contain a Slice object?
        if let slice = note.object as? xFlexAPI.Slice {
            
            // is it for this Panafall?
            if slice.panadapterId == self.panadapter!.id {
                
                // YES, log the event
                self._log.entry("Slice Removed, ID = \(slice.id)", level: .debug, source: self.kModule)
                
                // remove Slice property observers from the Slice being removed
                for keyPath in self._sliceKeyPaths {
                    
                    slice.removeObserver(self, forKeyPath: keyPath, context: &self._sliceContext)
                }
                
                // force a redraw
                self.redraw()
            }
        }
    }
    /// Process .tnfInitialized Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc private func tnfCreated(_ note: Notification) {
        
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? xFlexAPI.Tnf {
            
            // add Tnf property observers to the Tnf being added
            for keyPath in self._tnfKeyPaths {
                
                tnf.addObserver(self, forKeyPath: keyPath, options: .new, context: &self._tnfContext)
            }
            
            // force a redraw
            self.redraw()
        }
    }
    /// Process .tnfWillBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc private func tnfRemoved(_ note: Notification) {

        // does the Notification contain a Tnf object?
        if let tnf = note.object as? xFlexAPI.Tnf {
            
            // remove Tnf property observers from the Tnf being removed
            for keyPath in self._tnfKeyPaths {
                
                tnf.removeObserver(self, forKeyPath: keyPath, context: &self._tnfContext)
            }
            
            // force a redraw
            self.redraw()
        }
    }
    /// Process UserDefaults.didChangeNotification Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc private func defaultsChanged(_ note: Notification) {
        
        // force a redraw
        self.redraw()
    }

}
