//
//  SliceLayer.swift
//  xFlex
//
//  Created by Douglas Adams on 5/16/17.
//  Copyright © 2017 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI
import SwiftyUserDefaults

// --------------------------------------------------------------------------------
// MARK: - Slice Layer class implementation
// --------------------------------------------------------------------------------

class SliceLayer: CALayer, CALayerDelegate {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var slice: xFlexAPI.Slice!
    var params: Params!                                             // Radio & Panadapter references
    var markerHeight: CGFloat = 0.6                                 // height % for band markers
    
    var legendFont = NSFont(name: "Monaco", size: 12.0)
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _radio: Radio { return params.radio }
    fileprivate var _panadapterId: Radio.PanadapterId { return params.panadapterId }
    fileprivate var _panadapter: Panadapter { return _radio.panadapters[_panadapterId]! }
    
    fileprivate var _center: Int {return _radio.panadapters[_panadapterId]!.center }
    fileprivate var _bandwidth: Int { return _radio.panadapters[_panadapterId]!.bandwidth }
    fileprivate var _start: Int { return _center - (_bandwidth/2) }
    fileprivate var _end: Int  { return _center + (_bandwidth/2) }
    fileprivate var _hzPerUnit: CGFloat { return CGFloat(_end - _start) / bounds.width }

    fileprivate var _path = NSBezierPath()

    // constants
    fileprivate let kModule = "SliceLayer"                         // Module Name reported in log messages
    fileprivate let kSliceLayer = "slice"
    fileprivate let kFrequencyLineWidth: CGFloat = 3.0
    
    deinit {
        observations(slice, paths: _sliceKeyPaths, remove: true)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
    
    func start() {
        
        observations(slice, paths: _sliceKeyPaths)
    }
    
    /// Force a refresh of the display
    ///
    func redraw() {
        
        setNeedsDisplay()
    }
    
    /// Draw Layers
    ///
    /// - Parameters:
    ///   - layer: a CALayer
    ///   - ctx: context
    ///
    func draw(_ layer: CALayer, in ctx: CGContext) {
        
        guard let layerName = layer.name else {
            return
        }
        
        // setup the graphics context
        let context = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrent(context)
        
        // draw a layer
        switch layerName {
            
        case kSliceLayer:

            drawFilterOutlines(slice)
            
            drawFrequencyLines(slice)
            
        default:
            assert(true, "SliceLayer, draw - unknown layer name")
        }
        // restore the graphics context
        NSGraphicsContext.restoreGraphicsState()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Draw the Filter Outline
    ///
    /// - Parameter slice:  this Slice
    ///
    fileprivate func drawFilterOutlines(_ slice: xFlexAPI.Slice) {
        
        // calculate the Filter position & width
        let _filterPosition = CGFloat(slice.filterLow + slice.frequency - _start) / _hzPerUnit
        let _filterWidth = CGFloat(slice.filterHigh - slice.filterLow) / _hzPerUnit
        
        // draw the Filter
        let _rect = NSRect(x: _filterPosition, y: 0, width: _filterWidth, height: frame.height)
        _path.fillRect( _rect, withColor: Defaults[.sliceFilter], andAlpha: Defaults[.sliceFilterOpacity])
        
        _path.strokeRemove()
    }
    /// Draw the Frequency line
    ///
    /// - Parameter slice:  this Slice
    ///
    fileprivate func drawFrequencyLines(_ slice: xFlexAPI.Slice) {
        
        // set the width & color
        _path.lineWidth = kFrequencyLineWidth
        if slice.active { Defaults[.sliceActive].set() } else { Defaults[.sliceInactive].set() }
        
        // calculate the position
        let _freqPosition = ( CGFloat(slice.frequency - _start) / _hzPerUnit)
        
        // create the Frequency line
        _path.move(to: NSPoint(x: _freqPosition, y: frame.height))
        _path.line(to: NSPoint(x: _freqPosition, y: 0))
        
        // add the triangle cap (if active)
        if slice.active { _path.drawTriangle(at: _freqPosition, topWidth: 15, triangleHeight: 15, topPosition: frame.height) }
        
        _path.strokeRemove()
    }
    fileprivate let _sliceKeyPaths =                  // Slice keypaths to observe
        [
            "frequency"
        ]
    /// Add / Remove property observations
    ///
    /// - Parameters:
    ///   - object: the object of the observations
    ///   - paths: an array of KeyPaths
    ///   - add: add / remove (defaults to add)
    ///
    fileprivate func observations<T: NSObject>(_ object: T, paths: [String], remove: Bool = false) {
        
        // for each KeyPath Add / Remove observations
        for keyPath in paths {
            
            //            print("\(remove ? "Remove" : "Add   ") \(object.className):\(keyPath) in " + kModule)
            
            if remove { object.removeObserver(self, forKeyPath: keyPath, context: nil) }
            else { object.addObserver(self, forKeyPath: keyPath, options: [.initial, .new], context: nil) }
        }
    }
    /// Observe properties
    ///
    /// - Parameters:
    ///   - keyPath: the registered KeyPath
    ///   - object: object containing the KeyPath
    ///   - change: dictionary of values
    ///   - context: context (if any)
    ///
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        switch keyPath! {
            
        case "frequency":
            setNeedsDisplay()
            
//            print("frequency = \((object as! xFlexAPI.Slice).frequency)" )
            
        default:
            assert( true, "Invalid observation - \(keyPath!) in " + kModule)
            
        }
    }
}
