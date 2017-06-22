//
//  PanafallsViewController.swift
//  xFlex
//
//  Created by Douglas Adams on 4/30/16.
//  Copyright © 2016 Douglas Adams. All rights reserved.
//

import Cocoa
import xFlexAPI

//typealias Params = (radio: Radio, panadapterId: Radio.PanadapterId)     // Radio & Panadapter references
typealias Params = (radio: Radio, panadapter: Panadapter?, waterfall: Waterfall?)     // Radio & Panadapter references

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
//    func redrawAllSlices() {
//        
//        childViewControllers.forEach{ controller in (controller as! PanafallButtonViewController).redrawSlices() }
//    }
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
    
    /// Redraw Slices on a Panadapter (if any)
    ///
    /// - Parameter id: the Panadapter ID
    ///
//    fileprivate func redrawSlices(on id: Radio.PanadapterId) {
//        
//        // find the containing PanafallButtonViewControllers
//        for controller in childViewControllers where (controller.representedObject as! Params).panadapterId == id {
//            
//            // redraw its Slices
//            (controller as! PanafallButtonViewController).redrawSlices()
//        }
//    }

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
            var panafallButtonVc: PanafallButtonViewController?
            for vc in childViewControllers {
                if ((vc as! PanafallButtonViewController).representedObject as! Params).panadapter == pan {
                    panafallButtonVc = vc as? PanafallButtonViewController
                    break
                }
            }
            
            switch keyPath! {
            case #keyPath(Panadapter.center), #keyPath(Panadapter.bandwidth):
                panafallButtonVc?.redrawFrequencyLegend()
                panafallButtonVc?.redrawSlices()
                
            case #keyPath(Panadapter.minDbm), #keyPath(Panadapter.maxDbm):
                panafallButtonVc?.redrawDbLegend()
                
            default:
                assert( true, "Invalid observation - \(keyPath!) in " + kModule)
            }
            
        case is Waterfall:
            
            let waterfall = object as! Waterfall
            
            switch keyPath! {
                
            case #keyPath(Waterfall.gradientIndex):
                // load the new Gradient & recalc the levels
                _waterfallGradient.loadGradient(waterfall)
                fallthrough
                
            case #keyPath(Waterfall.autoBlackEnabled), #keyPath(Waterfall.blackLevel), #keyPath(Waterfall.colorGain):
                // recalc the levels
                _waterfallGradient.calcLevels(waterfall)
                
            default:
                assert( true, "Invalid observation - \(keyPath!) in " + kModule)
            }
            
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
        
        // a Panadapter was added
        NC.makeObserver(self, with: #selector(panadapterHasBeenAdded(_:)), of: .panadapterHasBeenAdded, object: nil)

        // a Panadapter should be removed
        NC.makeObserver(self, with: #selector(panadapterShouldBeRemoved(_:)), of: .panadapterShouldBeRemoved, object: nil)

        // a Waterfall was added
        NC.makeObserver(self, with: #selector(waterfallHasBeenAdded(_:)), of: .waterfallHasBeenAdded, object: nil)

        // a Waterfall should be removed
        NC.makeObserver(self, with: #selector(waterfallShouldBeRemoved(_:)), of: .waterfallShouldBeRemoved, object: nil)
    }
    //
    //  Panafall creation occurs in two steps:
    //
    //      Step 1 .panadapterHasBeenAdded
    //      Step 2 .waterfallHasBeenAdded
    //
    /// Process a newly added Panadapter
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func panadapterHasBeenAdded(_ note: Notification) {
        // a Panadapter model has been added to the Panadapters collection and Initialized
        
        // does the Notification contain a Panadapter?
        if let panadapter = note.object as? Panadapter {
            
            // YES, log the event
            _log.msg("Panadapter Initialized, ID = \(panadapter.id)", level: .debug, function: #function, file: #file, line: #line)
        }
    }
    /// Process a newly added Waterfall
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func waterfallHasBeenAdded(_ note: Notification) {
        // a Waterfall model has been added to the Waterfalls collection and Initialized
        
        // does the Notification contain a Waterfall?
        if let waterfall = note.object as? Waterfall {
            
            // YES, log the event
            _log.msg("Waterfall Initialized, ID = \(waterfall.id)", level: .debug, function: #function, file: #file, line: #line)
            
            // get the Panadapter for this Waterfall
            if let panadapter = _radioViewController.radio!.panadapters[waterfall.panadapterId] {
                
                // interact with the UI
                DispatchQueue.main.async { [unowned self] in
                    
                    // get the Storyboard containing a Panafall Button View Controller
                    let sb = NSStoryboard(name: NSStoryboard.Name(rawValue: self.kPanafallStoryboard), bundle: nil)
                    
                    // create a Panafall Button View Controller
                    let panafallButtonVc = sb.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: self.kPanafallButtonIdentifier)) as! PanafallButtonViewController
                    
                    // setup the Params tuple
                    panafallButtonVc.representedObject = Params(radio: self._radioViewController.radio!, panadapter: panadapter, waterfall: waterfall)
                    
                    // add PanafallButtonViewController to the PanafallsViewController
                    self.addChildViewController(panafallButtonVc)
                    
                    // tell the SplitView to adjust
                    self.splitView.adjustSubviews()
                    
                    // observe changes to Panadapter properties
                    self.observations(panadapter, paths: self._panadapterKeyPaths)
                    
                    // observe changes to Waterfall properties
                    self.observations(waterfall, paths: self._waterfallKeyPaths)
                }
            }
        }
    }
    //
    //  Panafall removal occurs in two steps:
    //
    //      Step 1 .panadapterShouldBeRemoved
    //      Step 2 .waterfallShouldBeRemoved
    //
    /// Process the removal of a Panadapter
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func panadapterShouldBeRemoved(_ note: Notification) {
        // a Panadapter model has been marked for removal and will be removed from the Panadapters collection
        
        // does the Notification contain a Panadapter?
        if let panadapter = note.object as? Panadapter {
            
            // YES, log the event
            _log.msg("Panadapter will be removed, ID = \(panadapter.id)", level: .debug, function: #function, file: #file, line: #line)

            // remove Panadapter property observers
            observations(panadapter, paths: _panadapterKeyPaths, remove: true)

            panadapter.delegate = nil
        }
        
    }
    /// Process the removal of a Waterfall
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc fileprivate func waterfallShouldBeRemoved(_ note: Notification) {
        // a Waterfall model has been marked for removal and will be removed from the Waterfalls collection
        
        // does the Notification contain a Waterfall?
        if let waterfall = note.object as? Waterfall {
            
            // YES, log the event
            _log.msg("Waterfall will be removed, ID = \(waterfall.id)", level: .debug, function: #function, file: #file, line: #line)
            
            // remove Waterfall property observers
            observations(waterfall, paths: _waterfallKeyPaths, remove: true)
            
            waterfall.delegate = nil
            
            // interact with the UI
            DispatchQueue.main.sync { [unowned self] in
                
                // find the Panafall Button View Controller containing the Waterfall
                for vc in self.childViewControllers where (((vc as! PanafallButtonViewController).representedObject) as! Params).waterfall == waterfall {
                    
                    let panafallButtonVc = vc as! PanafallButtonViewController
                    
                    // remove the entire PanafallButtonViewController
                    panafallButtonVc.removeFromParentViewController()
                    panafallButtonVc.dismiss(self)
                }
            }
        }
    }
    
}
