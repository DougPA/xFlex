//
//  PanafallsViewController.swift
//  xFlex
//
//  Created by Douglas Adams on 4/30/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI

typealias Params = (radio: Radio, panadapterId: Radio.PanadapterId)     // Radio & Panadapter references

class PanafallsViewController: NSSplitViewController {
    
    // ----------------------------------------------------------------------------
    // MARK: - Public properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    fileprivate var _notifications = [NSObjectProtocol]()                   // Notification observers
    fileprivate var _radioViewController: RadioViewController! { return representedObject as! RadioViewController }
        
    // constants
    fileprivate let _waterfallGradient = WaterfallGradient.sharedInstance
    fileprivate let _log = (NSApp.delegate as! AppDelegate)
    fileprivate let kModule = "PanafallsViewController"                     // Module Name reported in log messages
    fileprivate let kPanafallStoryboard = "Panafall"                        // Storyboard names    
    fileprivate let kPanafallButtonIdentifier = "Button"                    // Storyboard identifiers
    fileprivate let kPanadapterIdentifier = "Panadapter"
    fileprivate let kWaterfallIdentifier = "Waterfall"
    
    // ----------------------------------------------------------------------------
    // MARK: - Overridden methods
    
    /// the View has loaded
    ///
    override func viewDidLoad() {
        super.viewDidLoad()
        
//        print( kModule + " " + #function)
        
        // add notification subscriptions
        addNotifications()
    }
        
    deinit {

//        print( kModule + " " + #function)
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Public methods

//    /// Redraw the Grids on all Panadapters
//    ///
//    func redrawAllGrids() {
//        
//        childViewControllers.forEach{ controller in (controller as! PanafallButtonViewController).redrawGrid() }
//    }
    /// Redraw the FrequencyLegends on all Panadapters
    ///
    func redrawAllFrequencyLegends() {
        
        childViewControllers.forEach{ controller in (controller as! PanafallButtonViewController).redrawFrequencyLegend() }
    }
    /// Redraw the DbLegend on all Panadapters
    ///
    func redrawAllDbLegends() {
        
        childViewControllers.forEach{ controller in (controller as! PanafallButtonViewController).redrawDbLegend() }
    }
    /// Redraw the Slices on all Panadapters
    ///
    func redrawAllSlices() {
        
        childViewControllers.forEach{ controller in (controller as! PanafallButtonViewController).redrawSlices() }
    }
    /// Redraw all Panadapters (all components)
    ///
    open func redrawAll() {
        
        // force a redraw of each Panafall
        childViewControllers.forEach{ controller in (controller as! PanafallButtonViewController).redrawAll() }
    }    
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Private methods
    
    /// Redraw SLice on a Panadapter (if any)
    ///
    /// - Parameter id: the Panadapter ID
    ///
    fileprivate func redrawSlices(on id: Radio.PanadapterId) {
        
        // find the containing PanafallButtonViewControllers
        for controller in childViewControllers where (controller.representedObject as! Params).panadapterId == id {
            
            // redraw its Slices
            (controller as! PanafallButtonViewController).redrawSlices()
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Observation methods

    fileprivate let _panadapterKeyPaths =                   // Panadapter keypaths to observe
        [
            #keyPath(Panadapter.center),
            #keyPath(Panadapter.bandwidth),
            #keyPath(Panadapter.minDbm),
            #keyPath(Panadapter.maxDbm)
    ]
    fileprivate let _waterfallKeyPaths =                    // Waterfall keypaths to observe
        [
            #keyPath(Waterfall.autoBlackEnabled),
            #keyPath(Waterfall.blackLevel),
            #keyPath(Waterfall.colorGain),
            #keyPath(Waterfall.gradientIndex)
    ]
    fileprivate let _sliceKeyPaths =                        // Slice keypaths to observe
        [
            #keyPath(xFlexAPI.Slice.active),
            #keyPath(xFlexAPI.Slice.frequency),
            #keyPath(xFlexAPI.Slice.filterHigh),
            #keyPath(xFlexAPI.Slice.filterLow)
        ]
    fileprivate let _tnfKeyPaths =                          // Tnf keypaths to observe
        [
            #keyPath(Tnf.depth),
            #keyPath(Tnf.frequency),
            #keyPath(Tnf.permanent),
            #keyPath(Tnf.width)
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
            
//            print("\(remove ? "Remove" : "Add   ") \(object):\(keyPath) in " + kModule)

            if remove { object.removeObserver(self, forKeyPath: keyPath, context: nil) }
            else { object.addObserver(self, forKeyPath: keyPath, options: [.new], context: nil) }
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
        
        // what is the object?
        switch object {
        
        case is Panadapter:
            
            // get the Panadapter
            let pan = object as! Panadapter
            
            // find the viewController
            var x: PanafallButtonViewController?
            for vc in childViewControllers {
                if ((vc as! PanafallButtonViewController).representedObject as! Params).panadapterId == pan.id {
                    x = vc as? PanafallButtonViewController
                    break
                }
            }
            
            switch keyPath! {
            case #keyPath(Panadapter.center), #keyPath(Panadapter.bandwidth):
//                x?.redrawGrid()
                x?.redrawFrequencyLegend()
                x?.redrawSlices()
                
            case #keyPath(Panadapter.minDbm), #keyPath(Panadapter.maxDbm):
//                x?.redrawGrid()
                x?.redrawDbLegend()
                
            default:
                assert( true, "Invalid observation - \(keyPath!) in " + kModule)
            }
            
        case is Waterfall:
            
            let waterfall = object as! Waterfall
            
            switch keyPath! {
                
            case #keyPath(Waterfall.autoBlackEnabled), #keyPath(Waterfall.blackLevel), #keyPath(Waterfall.colorGain):
                // recalc the levels
                _waterfallGradient.calcLevels(waterfall)
                
            case #keyPath(Waterfall.gradientIndex):
                
                // load the new Gradient & recalc the levels
                _waterfallGradient.loadGradient(waterfall)
                _waterfallGradient.calcLevels(waterfall)
                
            default:
                assert( true, "Invalid observation - \(keyPath!) in " + kModule)
            }
            
        case is xFlexAPI.Slice:
            
            let slice = object as! xFlexAPI.Slice
                
            // redraw it
            redrawSlices(on: slice.panadapterId)
                
        case is Tnf:

            self.redrawAllSlices()
           
        default:
            break
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add subsciptions to Notifications
    ///     (as of 10.11, subscriptions are automatically removed on deinit when using the Selector-based approach)
    ///
    fileprivate func addNotifications() {
        
        // Panadapter initialized
        NC.makeObserver(self, with: #selector(panadapterInitialized(_:)), of: .panadapterInitialized, object: nil)

        // Panadapter will be removed
        NC.makeObserver(self, with: #selector(panadapterShouldBeRemoved(_:)), of: .panadapterShouldBeRemoved, object: nil)

        // Waterfall initialized
        NC.makeObserver(self, with: #selector(waterfallInitialized(_:)), of: .waterfallInitialized, object: nil)

        // Waterfall will be removed
        NC.makeObserver(self, with: #selector(waterfallShouldBeRemoved(_:)), of: .waterfallShouldBeRemoved, object: nil)

        // Slice initialized
        NC.makeObserver(self, with: #selector(sliceInitialized(_:)), of: .sliceInitialized, object: nil)

        // Slice should be removed
        NC.makeObserver(self, with: #selector(sliceShouldBeRemoved(_:)), of: .sliceShouldBeRemoved, object: nil)

        // Tnf initialized
        NC.makeObserver(self, with: #selector(tnfInitialized(_:)), of: .tnfInitialized, object: nil)

        // Tnf should be removed
        NC.makeObserver(self, with: #selector(tnfShouldBeRemoved(_:)), of: .tnfShouldBeRemoved, object: nil)
    }
    //
    //  Panafall creation:
    //
    //      Step 1 .panadapterInitialized
    //      Step 2 .waterfallInitialized
    //
    /// Process .panadapterInitialized Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func panadapterInitialized(_ note: Notification) {
        // a Panadapter model has been added to the Panadapters collection and Initialized
        
        // does the Notification contain a Panadapter?
        if let panadapter = note.object as? Panadapter {
            
            // YES, log the event
            _log.msg("Panadapter Initialized, ID = \(panadapter.id)", level: .debug, function: #function, file: #file, line: #line)
            
            // observe changes to Panadapter properties
            observations(panadapter, paths: _panadapterKeyPaths)
            
            // interact with the UI
            DispatchQueue.main.async { [unowned self] in
                
                // get the Storyboard containing a Panafall Button View Controller
                let sb = NSStoryboard(name: self.kPanafallStoryboard, bundle: nil)
                
                // create a Panafall Button View Controller
                let panafallButtonVc = sb.instantiateController(withIdentifier: self.kPanafallButtonIdentifier) as! PanafallButtonViewController
                
                // setup the Params tuple
                panafallButtonVc.representedObject = Params(radio: self._radioViewController.radio!, panadapterId: panadapter.id)
                
                // add PanafallButtonViewController to the PanafallsViewController
                self.addChildViewController(panafallButtonVc)
                
                // tell the SplitView to adjust
                self.splitView.adjustSubviews()
            }
        }
    }
    /// Process .waterfallInitialized Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func waterfallInitialized(_ note: Notification) {
        // a Waterfall model has been added to the Waterfalls collection and Initialized
        
        // does the Notification contain a Panadapter?
        if let waterfall = note.object as? Waterfall {
            
            // YES, log the event
            _log.msg("Waterfall Initialized, ID = \(waterfall.id)", level: .debug, function: #function, file: #file, line: #line)

            // observe changes to Waterfall properties
            observations(waterfall, paths: _waterfallKeyPaths)
        }
    }
    //
    //  Panafall removal:
    //
    //      Step 1 .panadapterShouldBeRemoved
    //      Step 2 .waterfallShouldBeRemoved
    //
    /// Process .panadapterShouldBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func panadapterShouldBeRemoved(_ note: Notification) {
        // a Panadapter model has been marked for removal and will be removed from the Panadapters collection
        
        // does the Notification contain a Panadapter?
        if let panadapter = note.object as? Panadapter {
            
            // YES, log the event
            _log.msg("Panadapter is being Removed, ID = \(panadapter.id)", level: .debug, function: #function, file: #file, line: #line)

            // remove Panadapter property observers
            observations(panadapter, paths: _panadapterKeyPaths, remove: true)
        }
        
    }
    /// Process .waterfallShouldBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func waterfallShouldBeRemoved(_ note: Notification) {
        // a Waterfall model has been marked for removal and will be removed from the Waterfalls collection
        
        // does the Notification contain a Waterfall?
        if let waterfall = note.object as? Waterfall {
            
            // YES, log the event
            _log.msg("Waterfall  Removed, ID = \(waterfall.id)", level: .debug, function: #function, file: #file, line: #line)
            
            // remove Waterfall property observers
            observations(waterfall, paths: _waterfallKeyPaths, remove: true)

            // interact with the UI
            DispatchQueue.main.async { [unowned self] in
                
                // find the Panafall Button View Controller for the Panafall containing the Waterfall
                for vc in self.childViewControllers where (((vc as! PanafallButtonViewController).representedObject) as! Params).panadapterId == waterfall.panadapterId {
                    
                    let panafallButtonVc = vc as! PanafallButtonViewController
                    
                    // remove the entire PanafallButtonViewController
                    panafallButtonVc.removeFromParentViewController()
                    panafallButtonVc.dismiss(self)
                }
            }
        }
    }
    /// Process .sliceInitialized Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func sliceInitialized(_ note: Notification) {
        
        // does the Notification contain a Slice object?
        if let slice = note.object as? xFlexAPI.Slice {
            
            // log the event
            _log.msg("Slice initialized, ID = \(slice.id), pan = \(slice.panadapterId)", level: .debug, function: #function, file: #file, line: #line)
            
            // observe changes to Slice properties
            observations(slice, paths: _sliceKeyPaths)
            
            // redraw all the slices on the affected Panadapter
            redrawSlices(on: slice.panadapterId)
        }
    }
    /// Process .sliceShouldBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func sliceShouldBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Slice object?
        if let slice = note.object as? xFlexAPI.Slice {
            
            // log the event
            _log.msg("Slice removed, ID = \(slice.id), pan = \(slice.panadapterId)", level: .debug, function: #function, file: #file, line: #line)
            
            // remove Slice property observers
            self.observations(slice, paths: self._sliceKeyPaths, remove: true)
            
            let panadapterId = slice.panadapterId
            
            // remove the Slice
            _radioViewController.radio?.slices[slice.id] = nil
            
            // redraw all the slices on the affected Panadapter
            redrawSlices(on: panadapterId)
        }
    }
    /// Process .tnfInitialized Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func tnfInitialized(_ note: Notification) {
        
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? xFlexAPI.Tnf {
            
            // YES, log the event
            _log.msg("Tnf initialized, ID = \(tnf.id)", level: .debug, function: #function, file: #file, line: #line)
            
            // observe changes to Tnf properties
            observations(tnf, paths: _tnfKeyPaths)
            
            // force a redraw of the Slice layer
            redrawAllSlices()
        }
    }
    /// Process .tnfShouldBeRemoved Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func tnfShouldBeRemoved(_ note: Notification) {
        
        // does the Notification contain a Tnf object?
        if let tnf = note.object as? xFlexAPI.Tnf {
            
            // YES, log the event
            _log.msg("Tnf removed, ID = \(tnf.id)", level: .debug, function: #function, file: #file, line: #line)

            // remove Tnf property observers
            observations(tnf, paths: _tnfKeyPaths, remove: true)
            
            // remove the Tnf
            _radioViewController.radio?.tnfs[tnf.id] = nil
            
            // force a redraw of the Slice layer
            redrawAllSlices()
        }
    }

    // ----------------------------------------------------------------------------
    // MARK: - Delegate Methods
    
}
