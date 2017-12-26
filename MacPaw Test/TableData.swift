
import Cocoa

// Everything conserning table data output
extension ViewController: NSTableViewDelegate, NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return files.allFiles.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // A dictionary of column's and their respective cell's IDs
        // Previously set in storyboard
        let columnToCellIds = [
            "NameColumnID": "NameCellID",
            "SizeColumnID": "SizeCellID",
            "CreatedColumnID": "CreatedCellID",
            "ModifiedColumnID": "ModifiedCellID",
            "HashColumnID": "HashCellID"
        ]
        var image: NSImage?
        var text: String = ""
        
        let item = files.allFiles[row]
        guard let tableColumn = tableColumn else { return nil }
        let columnId = tableColumn.identifier.rawValue
        
        switch columnId {
        case "NameColumnID":
            text = item.name
            image = item.icon
        case "SizeColumnID":
            text = item.sizeString
        case "CreatedColumnID":
            text = item.createdString
        case "ModifiedColumnID":
            text = item.modifiedString
        case "HashColumnID":
            text = item.hash
        default:
            return nil
        }
        
        // Create a table cell view with the data we defined
        // It's safe to unwrap the identifier due to the fact that we checked columnId just now
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: columnToCellIds[columnId]!), owner: nil) as? NSTableCellView {
            // Fill it with data
            cell.textField?.stringValue = text
            cell.imageView?.image = image ?? nil
            
            // A bit of customization
            cell.wantsLayer = true
            cell.layer?.backgroundColor = (row % 2 == 0) ? CGColor(gray: 1, alpha: 0.05) : CGColor.clear
            
            return cell
        }
        return nil
    }
    
    // Table's sorting has changed, sort the data and reload the table
    func tableView(_ tableView: NSTableView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
        reloadTableData(needSorting: true)
    }
    
    // Update number of selected items below the table
    func tableViewSelectionDidChange(_ notification: Notification) {
        updateUI()
    }
    
}
