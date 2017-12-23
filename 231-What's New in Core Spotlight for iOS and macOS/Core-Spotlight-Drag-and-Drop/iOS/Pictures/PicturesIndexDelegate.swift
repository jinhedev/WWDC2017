/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The Core Spotlight index delegate
*/

import Foundation
import CoreSpotlight
import PicturesFrameworkiOS

// CoreSpotlight delegate.
class PicturesIndexDelegate: NSObject, CSSearchableIndexDelegate {
    
    var datastore: Datastore = Datastore.sharedDatastore
    var index: CSSearchableIndex = CSSearchableIndex(name: navigationPointIndexName, protectionClass:
        FileProtectionType(rawValue: FileProtectionType.completeUntilFirstUserAuthentication.rawValue))
    
    func searchableIndex(_: CSSearchableIndex, reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        let group = DispatchGroup()
        // Index the view controllers.
        indexViewControllersIfNeeded(index: index)
        // Index the pictures.
        Datastore.sharedDatastore.indexSearchableItemsIfNeeded(group:group)
        // Call the acknowledgement handle when indexing has completed.
        group.notify(queue:datastore.queue) {
            acknowledgementHandler()
        }
    }
    
    func searchableIndex(_: CSSearchableIndex, reindexSearchableItemsWithIdentifiers
                         identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        let group = DispatchGroup()
        // Index the view controllers.
        indexViewControllers(index: index, identifiers: identifiers)
        // Index specific pictures.
        Datastore.sharedDatastore.indexItems(identifiers: identifiers, group: group)
        // Call the acknowledgement handler when indexing has completed.
        group.notify(queue:datastore.queue) {
            acknowledgementHandler()
        }
    }
    
    func updateSearchableItems() {
        // Use the datastore's background queue to handle indexing.
        let queue = datastore.queue
        
        queue.async {
            indexViewControllersIfNeeded(index: self.index)
        }
    }
    
}
