/*
See LICENSE folder for this sample’s licensing information.

Abstract:
App window's main view controller
*/

import Cocoa
import PicturesFrameworkMacOS

// Subclassing NSTableRowView for custom selected row appearance.
class PictureRowView: NSTableRowView {
    
    // Override drawSelection to draw a light gray background when the row is selected
    // instead of the default blue.
    override func drawSelection(in dirtyRect: NSRect) {
        let color = NSColor(calibratedWhite: 0, alpha: 0.1)
        color.setFill()
        bounds.fill()
    }
}

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    @IBOutlet weak var tableView: NSTableView?
    @IBOutlet weak var contentView: NSView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let confirmedTableView = self.tableView else {
            return
        }
        
        confirmedTableView.dataSource = self
        confirmedTableView.delegate = self
        confirmedTableView.rowHeight = 50
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return Datastore.sharedDatastore.pictures.count
    }
    
    // Create a small view with a thumbnail and title for the table.
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
        
        let thumbnail = NSImageView (frame: NSRect(x: 5, y: 5, width: 40, height: 40))
        thumbnail.image = (Datastore.sharedDatastore.pictures[row]).thumbnail
        view.addSubview(thumbnail)
        
        let label = NSTextField(frame: NSRect(x: 50, y: 16, width: 200, height: 18))
        label.stringValue = (Datastore.sharedDatastore.pictures[row]).name
        label.isBordered = false
        label.backgroundColor = nil
        view.addSubview(label)
        
        return view
    }
    
    // Show the DetailViewController for the selected Picture.
    func tableViewSelectionDidChange(_ notification: Notification) {
        
        guard let confirmedTableView = self.tableView,
            let confirmedContentView = self.contentView else {
            return
        }
        
        let selectedPicture = Datastore.sharedDatastore.pictures[confirmedTableView.selectedRow]
        
        // Make a DetailViewController with the selected picture.
        let detailViewController = DetailViewController(picture: selectedPicture)
        
        // Clear any preexisting views from the content area.
        for subview in confirmedContentView.subviews {
            subview.removeFromSuperview()
        }
        
        // Add the DetailViewController to the content area.
        confirmedContentView.addSubview(detailViewController.view)
        
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return PictureRowView(frame: NSRect(x: 0, y: 0, width: 200, height: 50))
    }
    
}

