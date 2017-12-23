/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Facilitates indexing content from view controllers for Core Spotlight
*/

import Foundation
import CoreSpotlight
import MobileCoreServices
import PicturesFrameworkiOS

let picturesNavigationDomainID = "com.example.apple-samplecode.Pictures.navigation"


struct PictureListViewControllerCoreSpotlightSupport {
    
    // Attributes relevant to indexing the PictureListViewController.
    static func attributeSet() -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String!)
        attributes.displayName = "Pictures Search"
        attributes.domainIdentifier = picturesNavigationDomainID
        return attributes
    }
    
    // Searchable item representing the PictureListViewController.
    static func searchableItem() -> CSSearchableItem {
        let item = CSSearchableItem(uniqueIdentifier: pictureListUserActivityIdentifier,
                                    domainIdentifier: picturesNavigationDomainID,
                                    attributeSet: attributeSet())
        
        return item
    }
}

struct GalleryViewControllerCoreSpotlightSupport {
    
    // Attributes relevant to indexing the GalleryViewController.
    static func attributeSet() -> CSSearchableItemAttributeSet {
        let attributes = CSSearchableItemAttributeSet(itemContentType: kUTTypeItem as String!)
        attributes.displayName = "Pictures Gallery"
        attributes.domainIdentifier = picturesNavigationDomainID
        return attributes
    }
    
    // Searchable item representing the GalleryViewController.
    static func searchableItem() -> CSSearchableItem {
        let item = CSSearchableItem(uniqueIdentifier: galleryUserActivityIdentifier,
                                    domainIdentifier: picturesNavigationDomainID,
                                    attributeSet: attributeSet())
        
        return item
    }

}

// Indexes all the view controllers if not already done.
func indexViewControllersIfNeeded(index: CSSearchableIndex) {
    
    let doneState = "Done"
    index.fetchLastClientState(completionHandler: { (data, _) in
        var stateFromData = ""
        if let confirmedData = data,
            let newState = String(data: confirmedData, encoding:String.Encoding.utf8) {
            stateFromData = newState
        }
        
        if stateFromData != doneState {
            let navigationSearchableItems: [CSSearchableItem] = [PictureListViewControllerCoreSpotlightSupport.searchableItem(),
                                                GalleryViewControllerCoreSpotlightSupport.searchableItem()]
            
            index.beginBatch()
            index.indexSearchableItems(navigationSearchableItems, completionHandler: nil)
            index.endBatch(withClientState: doneState.data(using:String.Encoding.utf8)!, completionHandler: nil)
        }
    })
}

func indexViewControllers(index: CSSearchableIndex, identifiers: [String]) {
    let doneState = "Done"
    var items = [CSSearchableItem] ()
    
    for identifier in identifiers {
        if identifier == pictureListUserActivityIdentifier {
            items.append(PictureListViewControllerCoreSpotlightSupport.searchableItem())
        } else if identifier == galleryUserActivityIdentifier {
            items.append(GalleryViewControllerCoreSpotlightSupport.searchableItem())
        }
    }
    
    index.beginBatch()
    index.indexSearchableItems(items, completionHandler:  nil)
    index.endBatch(withClientState: doneState.data(using:String.Encoding.utf8)!, completionHandler: nil)
}
