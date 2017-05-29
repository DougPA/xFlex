//
//  GridView.swift
//  StackPlay
//
//  Created by Douglas Adams on 11/12/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI

final class GridView : NSView {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var panafall: Panafall! {                   // Panafall associated with this view
        didSet {
            
            // pass the reference to the subview(s)
            sliceView.panafall = panafall
        }
    }
    var waterfall: Waterfall! {                 // Waterfall associated with this view
        didSet {
            
            // pass the reference to the subview(s)
            sliceView.waterfall = waterfall
        }
    }
    
    var markerHeight: CGFloat = 0.6             // height % for band markers
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet var sliceView: SliceView!
    
    private var _start: CGFloat { get { return panafall.center - (panafall.bandwidth/2) }}
    private var _end: CGFloat { get { return panafall.center + (panafall.bandwidth/2) }}
    private var _hzPerUnit: CGFloat { get { return (_end - _start) / self.frame.width }}

    private var _frequencyParams: FrequencyParamTuple {
        get { return (superview as! PanadapterView).frequencyParams(panafall.bandwidth) }}

    private let _p = ViewPreferences.sharedInstance          // View Preferences
    private var _path = NSBezierPath()
    // band & markers
    private lazy var _segments = Band.sharedInstance.segments

    private var _bandButtonViewController: BandButtonViewController!
    
    private let kDbLegendWidth: CGFloat = 35

    // ----------------------------------------------------------------------------
    // MARK: - Overridden Drawing methods
    
    //
    // Draw the Vertical & Horizontal grid lines
    //
    override func drawRect(dirtyRect: NSRect) {
        
        // draw the Grid lines
        drawGrid(dirtyRect)
        
        // draw the Band shading (if enabled)
        if _p.showMarkers { drawBandShading() }
    }
    
    deinit {

        // tell the Slice View to release its sub views (Button & Filter)
        sliceView.remove()
        
        // release the Slice View
        sliceView = nil
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal methods
    
    //
    // Remove this View and its sub views
    //
    func remove() {
    }
    
    func redraw() {
        needsDisplay = true
        
        sliceView.redraw()
    }

    // ----------------------------------------------------------------------------
    // MARK: - Private Drawing methods
    
    //
    // draw Horizontal & Vertical grid lines
    //
    private func drawGrid(dirtyRect: NSRect) {
        
        // set Line Width, Color & Dash
        _path.lineWidth = _p.gridLineWidth
        _p.grid.set()
        let dash: [CGFloat] = _p.gridLinesDashed ? [2.0, 1.0] : [2.0, 0.0]
        _path.setLineDash( dash, count: 2, phase: 0 )
        
        // calculate the Vertical Line spacings
        let freqRange = _end - _start
        let xIncrPerLegend = _frequencyParams.incr / _hzPerUnit
        
        // calculate the number & position of the Vertical Lines
        var numberOfLines = Int( freqRange / _frequencyParams.incr )
        let firstFreqValue = _start + (_frequencyParams.incr - (_start % _frequencyParams.incr))
        let firstFreqPosition = (firstFreqValue - _start) / _hzPerUnit

        // draw the vertical grid lines
        for i in 0...numberOfLines {
            let linePosition = firstFreqPosition + (CGFloat(i) * xIncrPerLegend)
            if linePosition < dirtyRect.width - kDbLegendWidth {
                _path.vLineAtX(linePosition, fromY: dirtyRect.height, toY: 0)
            }
        }
        
        // calculate the Horizontal Line spacings
        let dbRange = panafall.maxDbm - panafall.minDbm
        let yIncrPerDb = dirtyRect.height / dbRange
        let yIncrPerLine = yIncrPerDb * _p.dbLineSpacing

        // calculate the number & position of the Horizontal lines
        numberOfLines = Int( dbRange / _p.dbLineSpacing )
        let firstLinePosition = (-panafall.minDbm % _p.dbLineSpacing) * yIncrPerDb

        // draw the Horizontal grid lines
        for i in 0...numberOfLines {
            let linePosition = firstLinePosition + (CGFloat(i) * yIncrPerLine)
            // draw the line
            _path.hLineAtY(linePosition, fromX: 0, toX: dirtyRect.width - kDbLegendWidth )
        }
        _path.strokeRemove()
    }
    //
    // draw Band Segment Markers and Band Shading
    //
    private func drawBandShading() {

        // use solid lines
        _path.setLineDash( [2.0, 0.0], count: 2, phase: 0 )
        
        // filter for segments that overlap the panadapter frequency range
        let overlappingSegments = _segments.filter {
            (($0.start >= _start || $0.end <= _end) ||    // start or end in panadapter
                $0.start < _start && $0.end > _end) &&    // start -> end spans panadapter
                $0.enabled && $0.useMarkers}                                    // segment is enabled & uses Markers
        
        // ***** Band edges *****
        _p.bandEdge.set()           // set the color
        _path.lineWidth = 1         // set the width

        // filter for segments that contain a band edge
        let edgeSegments = overlappingSegments.filter {$0.startIsEdge || $0.endIsEdge}
        for s in edgeSegments {
            
            // is the start of the segment a band edge?
            if s.startIsEdge {
                
                // YES, draw a vertical line for the starting band edge
                _path.vLineAtX((s.start - _start) / _hzPerUnit, fromY: frame.height * markerHeight, toY: 0)
                _path.drawX(NSPoint(x: (s.start - _start) / _hzPerUnit, y: frame.height * markerHeight), halfWidth: 6)
            }

            // is the end of the segment a band edge?
            if s.endIsEdge {
                
                // YES, draw a vertical line for the ending band edge
                _path.vLineAtX((s.end - _start) / _hzPerUnit, fromY: frame.height * markerHeight, toY: 0)
                _path.drawX(NSPoint(x: (s.end - _start) / _hzPerUnit, y: frame.height * markerHeight), halfWidth: 6)
            }
        }
        _path.strokeRemove()
        
        // ***** Inside segments *****
        _p.segmentEdge.set()        // set the color
        _path.lineWidth = 1         // set the width
        var previousEnd:CGFloat = 0
        
        // filter for segments that contain an inside segment
        let insideSegments = overlappingSegments.filter {!$0.startIsEdge && !$0.endIsEdge}
        for s in insideSegments {
            
            // does this segment overlap the previous segment?
            if s.start != previousEnd {
                
                // NO, draw a vertical line for the inside segment start
                _path.vLineAtX((s.start - _start) / _hzPerUnit, fromY: frame.height * markerHeight - 6/2 - 1, toY: 0)
                _path.drawCircle(NSPoint(x: (s.start - _start) / _hzPerUnit, y: frame.height * markerHeight), radius: 6)
            }
            
            // draw a vertical line for the inside segment end
            _path.vLineAtX((s.end - _start) / _hzPerUnit, fromY: frame.height * markerHeight - 6/2 - 1, toY: 0)
            _path.drawCircle(NSPoint(x: (s.end - _start) / _hzPerUnit, y: frame.height * markerHeight), radius: 6)
            previousEnd = s.end
        }
        _path.strokeRemove()

        // ***** Band Shading *****
        _p.bandMarker.colorWithAlphaComponent(_p.bandMarkerOpacity).set()
        for s in overlappingSegments {
            
            // calculate start & end of shading
            let start = (s.start >= _start) ? s.start : _start
            let end = (_end >= s.end) ? s.end : _end
            
            // draw a shaded rectangle for the Segment
            let rect = NSRect(x: (start - _start) / _hzPerUnit, y: 0, width: (end - start) / _hzPerUnit, height: 20)
            NSBezierPath.fillRect(rect)
        }
        _path.strokeRemove()
    }

    
}
