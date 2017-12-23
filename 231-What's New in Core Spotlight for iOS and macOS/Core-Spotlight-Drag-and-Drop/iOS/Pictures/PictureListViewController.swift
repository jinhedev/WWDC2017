/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view controller with a table of pictures and a search bar
*/

import UIKit
import CoreSpotlight
import MobileCoreServices
import PicturesFrameworkiOS

class PictureListViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate {
    
    @IBOutlet weak var tableView: UITableView?
    @IBOutlet weak var searchBar: UISearchBar?
    
    var isSearching: Bool = false
    var foundItems: [Picture] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Allow the table cells to stretch across the whole screen even on landscape screens.
        self.tableView?.cellLayoutMarginsFollowReadableWidth = false
        
        // Do any additional setup after loading the view, typically from a nib.
        // Create a searchable user activity to inform CoreSpotlight of how often the user vists this view
        let userActivity = NSUserActivity(activityType: pictureListUserActivityIdentifier)
        let attributes = PictureListViewControllerCoreSpotlightSupport.attributeSet()
        attributes.relatedUniqueIdentifier = pictureListUserActivityIdentifier
        
        userActivity.title = attributes.displayName
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPublicIndexing = true
        userActivity.contentAttributeSet = attributes
        userActivity.isEligibleForHandoff = false
        userActivity.needsSave = true
        self.userActivity = userActivity
    }

    func updateDisplay() {
        tableView?.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching == false {
            return Datastore.sharedDatastore.count
        } else {
            return foundItems.count
        }
    }
    
    let cellReuseIdentifier = "infoCell"
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        // Reuse or create a cell for the table.
        var cell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier)
        
        if cell == nil {
            cell = UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: cellReuseIdentifier)
        }
        
        guard let confirmedCell = cell,
            let cellImageView = confirmedCell.imageView,
            let cellTextLabel = confirmedCell.textLabel else {
            fatalError()
        }
        
        var pictureToShow: Picture
        
        // Find the matching picture from either the DataStore or the search results.
        if !isSearching {
            pictureToShow = Datastore.sharedDatastore.getPicture(atIndex:indexPath.row)
            
        } else {
            pictureToShow = foundItems[indexPath.row]
        }
        
        cellTextLabel.text = pictureToShow.name
        cellImageView.image = pictureToShow.thumbnail
        cellImageView.contentMode = UIViewContentMode.scaleAspectFit
        
        return confirmedCell
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        // Start a new search.
        isSearching = true
        foundItems = []
        updateDisplay()
        search(userQuery: searchText)
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        // End a search.
        isSearching = false
        foundItems = []
        updateDisplay()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        guard let detailViewController = segue.destination as? DetailViewController,
            let confirmedTableView = self.tableView,
            let selectedRowPath = confirmedTableView.indexPathForSelectedRow else {
            return
        }
        
        // Select the picture from the search results if searching or the datastore if not.
        if isSearching {
            detailViewController.picture = foundItems[selectedRowPath.row]
        } else {
            detailViewController.picture = Datastore.sharedDatastore.getPicture(atIndex:selectedRowPath.row)
        }
    }
    
    // Currently running query.
    var query: CSSearchQuery?
    
    // Search from the search bar.
    func search(userQuery: String) {
        
        // Result set
        var results = [Picture]()
        
        // Cancel the previous query to avoid slowing the current search.
        query?.cancel()
        
        // Escape the user input.
        let escapedString = userQuery.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")

        // Create a query string.
        let queryString = "(**=\"" + escapedString + "*\"cwdt)" + " && contentType=\"" + (kUTTypeImage as String) + "\""
        
        // Create a query, request the attributes we need for display.
        let newQuery = CSSearchQuery(queryString: queryString, attributes: ["displayName", "thumbnailURL"])
        query = newQuery

        // Set a handler for results.
        // This will be a called 0 or more times.
        newQuery.foundItemsHandler = {
            (items: [CSSearchableItem]) -> Void in
            
            // Create Pictures for the query results.
            let foundPictures: [Picture] = items.map { item in
                
                guard let foundPicture = Datastore.sharedDatastore.picture(identifier: item.uniqueIdentifier) else {
                    fatalError()
                }
                return foundPicture
            }
            
            // Append pictures items to results array.
            results.append(contentsOf: foundPictures)
        }
        
        // Set a completion handler.
        // This will be called once.
        newQuery.completionHandler = {  (err) -> Void in
            // Sort the result array.
            results.sort(by: { (picture1, picture2) -> Bool in
                if picture1.name != picture2.name {
                    return picture1.name < picture2.name
                }
                return true
            })
            
            // Jump to the main queue to update the UI.
            DispatchQueue.main.async { () -> Void in
                // Update array of pictures.
                self.foundItems = results
                // And re-render table view.
                self.updateDisplay()
            }
        }

        // Start the query.
        newQuery.start()
        
    }

}

