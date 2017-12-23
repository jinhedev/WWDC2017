/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Indexes content for Core Spotlight Extension
*/

import CoreSpotlight
import Dispatch
#if os(iOS)
import MobileCoreServices
import UIKit
import PicturesFrameworkiOS
#else
import PicturesFrameworkMacOS
#endif

class IndexRequestHandler: CSIndexExtensionRequestHandler {

    override func searchableIndex(_ searchableIndex: CSSearchableIndex,
                                  reindexAllSearchableItemsWithAcknowledgementHandler acknowledgementHandler: @escaping () -> Void) {
        
        #if os(iOS)
        // First index navigation points, ie the table view and the gallery view
        // this sample does not implement navigations points for macOS at this time
        let index = CSSearchableIndex(name: navigationPointIndexName,
                                      protectionClass: FileProtectionType(rawValue: FileProtectionType.completeUntilFirstUserAuthentication.rawValue))
        indexViewControllersIfNeeded(index: index)
        #endif
        
        // Then continue with the pictures
        let group = DispatchGroup()
        Datastore.sharedDatastore.indexSearchableItemsIfNeeded(group:group)
        
        // Don't call the acknowledgement handler until all the indexing work is complete
        group.notify(queue:Datastore.sharedDatastore.queue)  { acknowledgementHandler() }
        
    }

    override func searchableIndex(_ searchableIndex: CSSearchableIndex, reindexSearchableItemsWithIdentifiers
                                  identifiers: [String], acknowledgementHandler: @escaping () -> Void) {
        
        // Reindex any items with the given identifiers and the provided index
        Datastore.sharedDatastore.indexItems(identifiers:identifiers)
        
        #if os(iOS)
        // Reindex any matching navigation points
        let index = CSSearchableIndex(name: navigationPointIndexName,
                                      protectionClass: FileProtectionType(rawValue: FileProtectionType.completeUntilFirstUserAuthentication.rawValue))
        indexViewControllers(index: index, identifiers: identifiers)
        #endif
        
        acknowledgementHandler()
    }
    
    override func data(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String) throws -> Data
    {
        // Provide indexed data requested for the dragged picture.
        guard let picture = Datastore.sharedDatastore.picture(identifier: itemIdentifier), typeIdentifier.isEqual(kUTTypeUTF8PlainText) else {
            fatalError()
        }
        
        // Just use the picture description here.
        return (picture.description?.data(using:String.Encoding.utf8))!
    }
    
    override func fileURL(for searchableIndex: CSSearchableIndex, itemIdentifier: String, typeIdentifier: String, inPlace: Bool) throws -> URL {
        
        // Provide indexed file URL requested for the dragged picture.
        guard let picture = Datastore.sharedDatastore.picture(identifier:itemIdentifier),
                typeIdentifier.isEqual(kUTTypeImage),
                let thumbnailURL = picture.thumbnailURL else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: nil)
        }
        
        // Just use the picture thumbnail URL here.
        return thumbnailURL
    }
}
