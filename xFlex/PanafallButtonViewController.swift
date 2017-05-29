//
//  PanafallButtonViewController.swift
//  xFlex
//
//  Created by Douglas Adams on 6/9/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI

// --------------------------------------------------------------------------------
// MARK: - Panafall Button View Controller class implementation
// --------------------------------------------------------------------------------

final class PanafallButtonViewController: NSViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // used by bindings in Popovers
    //Panafall
    var antList: [Radio.AntennaPort] { return _radio.antennaList }
    var average: Int {
        get { return _radio.panadapters[_panadapterId]!.average }
        set { _radio.panadapters[_panadapterId]!.average = newValue } }

    var daxIqChannel: Int {
        get { return _radio.panadapters[_panadapterId]!.daxIqChannel }
        set { _radio.panadapters[_panadapterId]!.daxIqChannel = newValue } }

    var fps: Int {
        get { return _radio.panadapters[_panadapterId]!.fps }
        set { _radio.panadapters[_panadapterId]!.fps = newValue } }

    var loopA: Bool {
        get { return _radio.panadapters[_panadapterId]!.loopAEnabled }
        set { _radio.panadapters[_panadapterId]!.loopAEnabled = newValue } }

    var rfGain: Int {
        get { return _radio.panadapters[_panadapterId]!.rfGain }
        set { _radio.panadapters[_panadapterId]!.rfGain = newValue } }

    var rxAnt: String {
        get { return _radio.panadapters[_panadapterId]!.rxAnt }
        set { _radio.panadapters[_panadapterId]!.rxAnt = newValue } }

    var weightedAverage: Bool {
        get { return _radio.panadapters[_panadapterId]!.weightedAverageEnabled }
        set { _radio.panadapters[_panadapterId]!.weightedAverageEnabled = newValue } }

    // Waterfall
    var autoBlackEnabled: Bool {
        get { return _radio.waterfalls[_panadapter.waterfallId]!.autoBlackEnabled }
        set { _radio.waterfalls[_panadapter.waterfallId]!.autoBlackEnabled = newValue } }

    var blackLevel: Int {
        get { return _radio.waterfalls[_panadapter.waterfallId]!.blackLevel }
        set { _radio.waterfalls[_panadapter.waterfallId]!.blackLevel = newValue } }

    var colorGain: Int {
        get { return _radio.waterfalls[_panadapter.waterfallId]!.colorGain }
        set { _radio.waterfalls[_panadapter.waterfallId]!.colorGain = newValue } }

    var gradientIndex: Int {
        get { return _radio.waterfalls[_panadapter.waterfallId]!.gradientIndex }
        set { _radio.waterfalls[_panadapter.waterfallId]!.gradientIndex = newValue } }

    var gradientName: String { return gradientNames[_radio.waterfalls[_panadapter.waterfallId]!.gradientIndex] }

    var gradientNames: [String] { return WaterfallGradient.sharedInstance.gradientNames }

    var lineDuration: Int {
        get { return _radio.waterfalls[_panadapter.waterfallId]!.lineDuration }
        set { _radio.waterfalls[_panadapter.waterfallId]!.lineDuration = newValue } }
    
    let daxChoices = ["None", "1", "2", "3", "4"]

    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _panafallViewController: PanafallViewController!
    
    fileprivate var _radio: Radio { return (representedObject as! Params).radio }
    fileprivate var _panadapterId: Radio.PanadapterId { return (representedObject as! Params).panadapterId }
    fileprivate var _panadapter: Panadapter { return _radio.panadapters[_panadapterId]! }

    fileprivate var _center: Int {return _radio.panadapters[_panadapterId]!.center }
    fileprivate var _bandwidth: Int { return _radio.panadapters[_panadapterId]!.bandwidth }
    fileprivate var _minDbm: CGFloat { return _radio.panadapters[_panadapterId]!.minDbm }
    fileprivate var _maxDbm: CGFloat { return _radio.panadapters[_panadapterId]!.maxDbm }

    // constants
    fileprivate let kModule = "PanafallButtonViewController" // Module Name reported in log messages
    fileprivate let kPanafallEmbed = "PanafallEmbed"
    fileprivate let kBandPopover = "BandPopover"
    fileprivate let kAntennaPopover = "AntennaPopover"
    fileprivate let kDisplayPopover = "DisplayPopover"
    fileprivate let kDaxPopover = "DaxPopover"
    fileprivate let kPanadapterSplitViewItem = 0
    fileprivate let kWaterfallSplitViewItem = 1
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
        
    /// Prepare to execute a Segue
    ///
    /// - Parameters:
    ///   - segue: a Segue instance
    ///   - sender: the sender
    ///
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {

        switch segue.identifier! {
        
        case kPanafallEmbed:                            // this will always occur first
            
            // pass a copy of the Params
            (segue.destinationController as! NSViewController).representedObject = representedObject
            
            // save a reference to the Panafall view controller
            _panafallViewController = segue.destinationController as! PanafallViewController
            _panafallViewController!.representedObject = representedObject as! Params
            
            // give the PanadapterViewController & waterfallViewControllers a copy of the Params
            _panafallViewController!.splitViewItems[kPanadapterSplitViewItem].viewController.representedObject = representedObject as! Params
            _panafallViewController!.splitViewItems[kWaterfallSplitViewItem].viewController.representedObject = representedObject as! Params

        case kAntennaPopover, kDisplayPopover, kDaxPopover:
            
            // pass the Popovers a reference to this controller
            (segue.destinationController as! NSViewController).representedObject = self
            
        case kBandPopover:
            
            // pass the Band Popover a copy of the Params
            (segue.destinationController as! NSViewController).representedObject = representedObject
            
        default:
            break
        }
    }
    /// the Class is being destroyed
    ///
    deinit {
        
//        print( kModule + " " + #function)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods
        
    /// Redraw the FrequencyLegends on all Panadapters
    ///
    func redrawFrequencyLegend() {
        
        _panafallViewController?.redrawFrequencyLegend()
    }
    /// Redraw the DbLegends on all Panadapters
    ///
    func redrawDbLegend() {
        
        _panafallViewController?.redrawDbLegend()
    }
    /// Redraw the Slices on all Panadapters
    ///
    func redrawSlices() {
        
        _panafallViewController?.redrawSlices()
    }
    /// Redraw this Panafall
    ///
    public func redrawAll() {
        _panafallViewController.redrawAll()
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Zoom + (decrease bandwidth)
    ///
    /// - Parameter sender: the sender
    ///
    @IBAction func zoomPlus(_ sender: NSButton) {
        
        // are we near the minimum?
        if _bandwidth / 2 > _panadapter.minBw {
            
            // NO, make the bandwidth half of its current value
            _panadapter.bandwidth = _bandwidth / 2
            
        } else {
            
            // YES, make the bandwidth the minimum value
            _panadapter.bandwidth = _panadapter.minBw
        }
    }
    /// Zoom - (increase the bandwidth)
    ///
    /// - Parameter sender: the sender
    ///
    @IBAction func zoomMinus(_ sender: NSButton) {
        // are we near the maximum?
        if _bandwidth * 2 > _panadapter.maxBw {
            
            // YES, make the bandwidth maximum value
            _panadapter.bandwidth = _panadapter.maxBw
            
        } else {
            
            // NO, make the bandwidth twice its current value
            _panadapter.bandwidth = _bandwidth * 2
        }
    }
    /// Close this Panafall
    ///
    /// - Parameter sender: the sender
    ///
    @IBAction func close(_ sender: NSButton) {
        
        // tell the Radio to remove this Panafall
        _radio.removePanafall(_panadapter.id)
    }
    /// Create a new Slice (if possible)
    ///
    /// - Parameter sender: the sender
    ///
    @IBAction func rx(_ sender: NSButton) {
        
        // tell the Radio (hardware) to add a Slice on this Panadapter
        _radio.createSlice(panadapter: _panadapter)
    }
    /// Create a new Tnf
    ///
    /// - Parameter sender: the sender
    ///
    @IBAction func tnf(_ sender: NSButton) {
        
        // tell the Radio (hardware) to add a Tnf on this Panadapter
        _radio.createTnf(frequency: 0, panadapter: _panadapter)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Delegate methods
    
}
