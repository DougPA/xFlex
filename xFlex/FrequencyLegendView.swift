//
//  FrequencyLegendView.swift
//  StackPlay
//
//  Created by Douglas Adams on 11/12/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI

final class FrequencyLegendView : NSView {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    var panafall: Panafall!                     // Panafall associated with this view
    var font = NSFont( name: "Menlo-Bold", size: 12 )!  // frequencly legend font
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    private let _p = ViewPreferences.sharedInstance          // View Preferences

    private var _start: CGFloat { get { return panafall.center - (panafall.bandwidth/2) }}
    private var _end: CGFloat { get { return panafall.center + (panafall.bandwidth/2) }}
    private var _hzPerUnit: CGFloat { get { return (_end - _start) / self.frame.width }}
    private var _frequencyParams: FrequencyParamTuple {
        get { return (superview as! PanadapterView).frequencyParams(panafall.bandwidth) }}

    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    deinit {
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden Drawing methods

    //
    // draw the Frequency Legend view
    //
    override func drawRect(dirtyRect: NSRect) {
        
        // set the Background color
        layer?.backgroundColor = _p.frequencyBackground.CGColor

        // remember the position of the previous legend (left to right)
        var previousLegendPosition: CGFloat = 0.0

        // setup the Font & Font color
        let attributes = [ NSForegroundColorAttributeName: _p.frequencyLegend,  NSFontAttributeName: font]
        
        // calculate the spacings
        let freqRange = _end - _start
        let xIncrPerLegend = _frequencyParams.incr / _hzPerUnit
        
        // calculate the number & position of the legend marks
        let numberOfMarks = Int( freqRange / _frequencyParams.incr )
        let firstFreqValue = _start + (_frequencyParams.incr - (_start % _frequencyParams.incr))
        let firstFreqPosition = (firstFreqValue - _start) / _hzPerUnit
        
        for i in 0...numberOfMarks {
            let legendPosition = firstFreqPosition + (CGFloat(i) * xIncrPerLegend)
            
            // calculate the Frequency legend value & width
            let legendLabel = String(format: _frequencyParams.format, (firstFreqValue + (CGFloat(i) * _frequencyParams.incr)) / 1_000_000)
            let legendWidth = legendLabel.sizeWithAttributes( attributes).width
            
            // skip the legend if it would overlap the start or end or if it would be too close to the previous legend
            if legendPosition - legendWidth > 0 && legendPosition + legendWidth < dirtyRect.width && legendPosition - previousLegendPosition > 1.2 * legendWidth {
                // draw the legend
                legendLabel.drawAtPoint( NSMakePoint( legendPosition - (legendWidth/2), 1), withAttributes: attributes)
                // save the position for comparison when drawing the next legend
                previousLegendPosition = legendPosition
            }
        }
        
    }
}
