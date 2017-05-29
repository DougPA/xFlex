//
//  LogViewController.swift
//  xFlex
//
//  Created by Douglas Adams on 9/6/15.
//  Copyright © 2015 Douglas Adams. All rights reserved.
//

//
//  When the Log View is displayed, it opens (by default) on the Log tab.
//  A copy of the current Log is made and displayed. As long as the Log window
//  is still being displayed, it captures .LogEntryWasAdded notifications
//  and adds new Log entries to the existing copy of the Log.
//
//  When the Commands tab is selected a copy of the current Commands list is made.
//  Only a limited number of Commands are retained (default = 256).
//  When the maximum is reached the oldest command is deleted and the new 
//  command appended. As long as the Log window is still being displayed, 
//  it captures .CommandEntryWasAdded notifications and adds new Command 
//  entries to the existing copy of the Commands list.
//

import Cocoa
import xFlexAPI

// --------------------------------------------------------------------------------
// MARK: - AlertSound Enum
// --------------------------------------------------------------------------------

enum AlertSound : String {
    case Basso
    case Blow
    case Bottle
    case Frog
    case Funk
    case Glass
    case Hero
    case Morse
    case Ping
    case Pop
    case Purr
    case Sosumi
    case Submarine
    case Tink
}

// --------------------------------------------------------------------------------
// MARK: - Log View Controller class implementation
// --------------------------------------------------------------------------------

final class LogViewController : NSViewController, NSTabViewDelegate, NSTableViewDelegate, NSTableViewDataSource {
    
    // ----------------------------------------------------------------------------
    // MARK: - Internal properties
    
    // ----------------------------------------------------------------------------
    // MARK: - Private properties
    
    @IBOutlet fileprivate weak var _logTableView: NSTableView!
    @IBOutlet var _filterByPopUp: NSPopUpButton!
    @IBOutlet fileprivate weak var _tabView: NSTabView!
    @IBOutlet fileprivate weak var _commandTableView: NSTableView!
    
    fileprivate var _notifications = [NSObjectProtocol]()   // Notification observers
    
    fileprivate let _log = Log.sharedInstance
    fileprivate var _logCopy: [LogEntry]?
    fileprivate var _commandCopy: [String]?
    fileprivate var _logNotification: NSObjectProtocol!
    fileprivate var _commandsNotification: NSObjectProtocol!
    fileprivate var outboundColor = NSColor(srgbRed: 0.0, green: 1.0, blue: 0.0, alpha: 0.1)
    fileprivate var inboundColor = NSColor(srgbRed: 0.0, green: 0.0, blue: 0.0, alpha: 0.1)
    
    fileprivate let _autosaveName = "LogWindow"              // AutoSave name for the Log window
    
    // ----------------------------------------------------------------------------
    // MARK: - Overrides
    
    override func viewWillAppear() {
        
        super.viewWillAppear()
        
        view.window!.setFrameUsingName(_autosaveName)
    }
    
    override func viewWillDisappear() {
        
        super.viewWillDisappear()
        
        view.window!.saveFrame(usingName: _autosaveName)
    }
    
    override func viewDidLoad() {
        
        super.viewDidLoad()

//        _filterByPopUp.autoenablesItems = false
        
        _tabView.delegate = self
        
        // get a copy of the Log
        _logCopy = _log.logCopy()
        
        // load the Commands
        _commandCopy = _log.commandCopy()
        
        // populate the "Filter By" button choices
        _filterByPopUp.addItems(withTitles: MessageLevel.names())
        
        // set the Tag for each choice to it's corresponding Raw Value
        let values = MessageLevel.values()
        for (index, item) in _filterByPopUp.itemArray.enumerated() {
            item.tag = values[index]
        }
        // select Info as the default FilterBy
        _filterByPopUp.selectItem(withTag: MessageLevel.info.rawValue)
        
        addNotifications()
        
        // refresh the Log table
        reloadTable(_logTableView)
    }
    
    override func viewDidDisappear() {
        
        super.viewDidDisappear()
    }
        
    // ----------------------------------------------------------------------------
    // MARK: - Internal Methods
    
    /// Change the FilterBy selection
    ///
    /// - Parameter filterLevel: MessageLevel to filter on
    ///
    func chooseFilter(_ filterLevel: MessageLevel) {
        
        // select the desired MessageLevel
        _filterByPopUp.selectItem(withTag: filterLevel.rawValue)
        
        // refresh the Log table
        reloadTable( _logTableView )
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Action methods
    
    /// Open a Save dialog, choose a file name and folder and save the Log
    ///
    /// - Parameter sender: the Button
    ///
    @IBAction func saveButton(_ sender: NSButton) {
        
        // which tab is in view?
        let isLog = (_tabView.selectedTabViewItem!.label == "Log")
        
        // open a File Save dialog
        let panel = NSSavePanel()
        panel.allowedFileTypes = ["txt"]
        panel.nameFieldStringValue = (isLog ? "xFlexLog" : "xFlexCommands")
        panel.directoryURL = URL(fileURLWithPath: ("~/Desktop" as NSString).expandingTildeInPath, isDirectory: true)
        
        panel.beginSheetModal(for: view.window!, completionHandler: { (returnCode) -> Void in
            if returnCode == NSFileHandlingPanelOKButton {
                if isLog {
                    
                    // write the Log to the designated file
                    self._log.writeLogToFileURL(panel.url!, filterBy: MessageLevel(rawValue: self._filterByPopUp.selectedTag()))
                
                } else {
                    
                    // write the Commands list to the designated file
                    self._log.writeCommandsToFileURL(panel.url!)
                }
            }
        })
    }
    /// Respond to a change in the FilterBy popup button
    ///
    /// - Parameter sender: the Popup Button
    ///
    @IBAction func filterByChanged(_ sender: NSPopUpButton) {
        reloadTable(_logTableView)
    }
    
    /// Clear the Table
    ///
    /// - Parameter sender: the NSButton
    ///
    @IBAction func clear(_ sender: NSButton) {
        _logCopy = [LogEntry]()
        
        reloadTable(_logTableView)
    }
    // ----------------------------------------------------------------------------
    // MARK: - Private Methods
    
    /// Reload a table and assure that the last entry is visible
    ///
    /// - Parameter table: the Table
    ///
    fileprivate func reloadTable(_ table: NSTableView) {
        
        // reload the table
        table.reloadData()

        // make sure the last row is visible
        if table.numberOfRows > 0 {
            
            table.scrollRowToVisible(table.numberOfRows - 1)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - Observation Methods
    
    // ----------------------------------------------------------------------------
    // MARK: - Notification Methods
    
    /// Add Notifications
    ///
    fileprivate func addNotifications() {
        
        // Entry added to the Log
        NotificationCenter.default.addObserver(self, selector: #selector(logEntryAdded(_:)),
                                               name: NSNotification.Name(rawValue: NotificationType.logEntryWasAdded.rawValue),
                                               object: nil)        
        // Entry added to the Log
        NotificationCenter.default.addObserver(self, selector: #selector(commandEntryAdded(_:)),
                                               name: NSNotification.Name(rawValue: NotificationType.commandEntryWasAdded.rawValue),
                                               object: nil)
    }
    /// Process .logEntryWasAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc private func logEntryAdded(_ note: Notification) {

        // interact with the UI
        DispatchQueue.main.async {
            
            // add the new entry to the existing copy of the Log
            self._logCopy?.append(note.object as! LogEntry)
            
            // refresh the Log table when a new entry occurs
            self.reloadTable(self._logTableView)
        }
    }
    /// Process .commandEntryWasAdded Notification
    ///
    /// - Parameter note: a Notification instance
    ///
    @objc private func commandEntryAdded(_ note: Notification) {
        
        // interact with the UI
        DispatchQueue.main.async {
            
            let newCommand = note.object as! String
            
            // skip "Pings" and "Rnn|0|" replies
            if !newCommand.hasSuffix("|ping\n") && !newCommand.hasSuffix("|0|\n") {
                
                // add the new entry to the existing copy of the Commands
                self._commandCopy?.append(newCommand)
                
                // refresh the Log table when a new entry occurs
                self.reloadTable(self._commandTableView)
            }
        }
    }
    // ----------------------------------------------------------------------------
    // MARK: - NSTabView delegate methods
    
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        
        if tabViewItem!.label == "Log" {

            reloadTable(_logTableView)
            
        } else {
            
            reloadTable(_commandTableView)
        }
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - NSTableView DataSource methods
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        let rowCount: Int
        
        if tableView == _logTableView {
            
            // get a current copy of the Log (if not already present)
            if _logCopy == nil { _logCopy = _log.logCopy() }
            
            rowCount = _logCopy!.filter { $0.level.rawValue >= _filterByPopUp.selectedTag() }.count

        } else {
            
            // get a current copy of the Commands (if not already present)
            if _commandCopy == nil { _commandCopy = _log.commandCopy() }
            
            rowCount = _commandCopy!.count
        }
        
        return rowCount
    }
    
    // ----------------------------------------------------------------------------
    // MARK: - NSTableView Delegate methods
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let view: NSTableCellView
        
        if tableView == _logTableView {

            // get a view for the cell
            view = tableView.make(withIdentifier: tableColumn!.identifier, owner:self) as! NSTableCellView
            
            // Set the stringValue of the cell's text field to the appropriate field
            view.textField!.backgroundColor = _logCopy!.filter { $0.level.rawValue >= _filterByPopUp.selectedTag() }[row].level.color
            view.textField!.stringValue = _logCopy!.filter { $0.level.rawValue >= _filterByPopUp.selectedTag() }[row].valueForId(tableColumn!.identifier) ?? ""
            
            // remove the date from the timeStamp
            if tableColumn!.identifier == "timeStamp" { view.textField!.stringValue = String(view.textField!.stringValue.characters.dropFirst(11)) }
            
        } else {

            // get a view for the cell
            view = tableView.make(withIdentifier: tableColumn!.identifier, owner:self) as! NSTableCellView
            
            // Set the stringValue of the cell's text field to the appropriate field
            view.textField!.backgroundColor = _commandCopy![row].uppercased().hasPrefix("C") ? outboundColor : inboundColor
            view.textField!.stringValue = _commandCopy![row]
            
        }
        
        return view
    }
}
