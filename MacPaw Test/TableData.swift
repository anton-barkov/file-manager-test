
import Cocoa

extension ViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    fileprivate enum CellIdentifiers {
        static let SelectCellID = "SelectCellID"
        static let NameCell = "NameCellID"
        static let SizeCell = "SizeCellID"
        static let CreatedCell = "CreatedCellID"
        static let ModifiedCell = "ModifiedCellID"
        static let HashCell = "HashCellID"
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return files.allFiles.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    
        var image: NSImage?
        var text: String = ""
        var cellIdentifier: String = ""
        
        let item = files.allFiles[row]
        
        if tableColumn == tableView.tableColumns[0] {
            text = item.name
            image = item.icon
            cellIdentifier = CellIdentifiers.NameCell
        } else if tableColumn == tableView.tableColumns[1] {
            text = item.sizeString
            cellIdentifier = CellIdentifiers.SizeCell
        } else if tableColumn == tableView.tableColumns[2] {
            text = item.createdString
            cellIdentifier = CellIdentifiers.CreatedCell
        } else if tableColumn == tableView.tableColumns[3] {
            text = item.modifiedString
            cellIdentifier = CellIdentifiers.ModifiedCell
        } else if tableColumn == tableView.tableColumns[4] {
            text = item.hash
            cellIdentifier = CellIdentifiers.HashCell
        }
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            cell.imageView?.image = image ?? nil
            cell.wantsLayer = true
            cell.layer?.backgroundColor = (row % 2 == 0) ? CGColor(gray: 1, alpha: 0.05) : CGColor.clear
            return cell
        }
        return nil
    }
    
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        reloadTableData(needSorting: true)
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateUI()
    }
    
}
