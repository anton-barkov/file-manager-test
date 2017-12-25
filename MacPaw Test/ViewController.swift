//
//  ViewController.swift
//  MacPaw Test
//
//  Created by Anton Barkov on 21.12.2017.
//  Copyright © 2017 Anton Barkov. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {
    
    let files = Files.shared
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var noFilesMessage: NSTextField!
    @IBOutlet weak var removeFilesButton: NSButton!
    @IBOutlet weak var infoLabel: NSTextField!
    
    @IBAction func addFilesClicked(_ sender: Any) {
        guard let window = view.window else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        
        panel.beginSheetModal(for: window) { (result) in
            if result == NSApplication.ModalResponse.OK {
                outerLoop: for url in panel.urls {
                    // ignore already added files
                    for f in self.files.allFiles {
                        if(f.url == url) { continue outerLoop }
                    }
                    self.files.appendFile(url: url)
                }
                self.reloadTableData()
            }
        }
    }
    
    @IBAction func removeFilesClicked(_ sender: Any) {
        files.removeFiles(atIndexes: tableView.selectedRowIndexes)
        reloadTableData()
    }
    
    @IBAction func selectAllClicked(_ sender: Any) {
        tableView.selectAll(nil)
    }
    
    @IBAction func deselectAllClicked(_ sender: Any) {
        tableView.deselectAll(nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
    }
    
    func reloadTableData(needSorting: Bool = false) {
        if(needSorting) {
            if let descriptor = tableView.sortDescriptors.first, descriptor.key != nil {
                files.sortData(field: descriptor.key!, ascending: descriptor.ascending)
            }
        }
        tableView.reloadData()
        updateUI()
    }
    
    func updateUI() {
        let totalFilesCount = files.allFiles.count
        let selectedFilesCount = tableView.selectedRowIndexes.count
        let disableWhenNothingSelected = [removeFilesButton]
        let hideWhenFilesSelected = [noFilesMessage]
        
        for object in disableWhenNothingSelected {
            object?.isEnabled = (selectedFilesCount > 0)
        }
        for object in hideWhenFilesSelected {
            object?.isHidden = (totalFilesCount > 0)
        }
        
        infoLabel.stringValue = "\(totalFilesCount) files total, \(selectedFilesCount) selected"
    }

}

class BackgroundGradientView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let gradient = NSGradient(colors: [
            NSColor(red: 96 / 255, green: 108 / 255, blue: 136 / 255, alpha: 1),
            NSColor(red: 63 / 255, green: 76 / 255, blue: 107 / 255, alpha: 1)
            ])
        gradient?.draw(in: dirtyRect, angle: 90)
    }
}
