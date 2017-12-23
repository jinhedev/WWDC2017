/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Faciliting access to pictures
*/
import Foundation
import CoreSpotlight

public class Datastore: NSObject {
    static var _sharedDataStore: Datastore = Datastore()
    public class var sharedDatastore: Datastore {
        return _sharedDataStore
    }
    
    class var thumbnailPath: String {
        let fm = FileManager.default
        
        guard let directory = fm.containerURL(forSecurityApplicationGroupIdentifier: "group.com.example.apple-samplecode.Pictures") else {
            return ""
        }
        
        let thumbnailDir = directory.path.appending("/thumbnails")
        
        return thumbnailDir
    }
    
    public var pictures: [Picture] = []
    public let queue = DispatchQueue(label: "indexing queue", qos:DispatchQoS.background)
    var searchableIndex: CSSearchableIndex = CSSearchableIndex(name:"pictures" )
    
    public var count: Int {
        return pictures.count
    }

    public func getPicture(atIndex index: Int) -> Picture {
        return pictures[index]
    }

    override init() {
        super.init()
        let fm = FileManager.default
        let path = Datastore.thumbnailPath
        let newDirectory = !fm.fileExists(atPath:path )
        
        if newDirectory {
            do {
                try fm.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                NSLog("failed to create directory for thumbnails : " + path)
                fatalError()
            }
        }
        
        // Load all the images in Pictures.plist
        load()
        
        if newDirectory {
            queue.async {
                // Index all items on a background queue if we haven't done so before.
                self.indexItems(startingIndex:0)
            }
        } else {
            indexSearchableItemsIfNeeded()
        }
    }
    
    // Load all Pictures from Pictures.plist
    func load() {
        let frameworkBundle = Bundle(for: Datastore.self)
        
        guard let picturePlistURL = frameworkBundle.url(forResource:"Pictures", withExtension:"plist"),
            let plistObjects = NSArray(contentsOf: picturePlistURL) as? [[String:AnyObject]] else {
                return
        }
        
        for plistGlob in plistObjects {
            guard let dictionary = plistGlob as [String:AnyObject]?,
                let pictureFromPlist = Picture(dictionary: dictionary) else {
                    continue
            }
            pictures.append(pictureFromPlist)
        }
    }
    
    // Find a picture with a particular identifier.
    public func picture(identifier: String) -> Picture? {
        for element in pictures where element.identifier == identifier {
            return element
        }
        return nil
    }
    
}

extension Datastore {
    
    public func indexSearchableItemsIfNeeded(group: DispatchGroup? = nil) {
        
        let index: CSSearchableIndex = self.searchableIndex
        // Enter dispatch group as we have more work to do.
        if let group = group {
            group.enter()
        }
        
        index.fetchLastClientState(completionHandler: { (data, error) in
            if error == nil {
                var number = 0
                if let unwrappedData = data,
                    let datastring = String(data: unwrappedData, encoding: String.Encoding.utf8),
                    let numberFromData = Int(datastring) {
                    number = numberFromData
                }
                
                if number < self.pictures.count {
                    self.queue.async {
                        // Index items from the background queue, starting where we left off.
                        // Pass group to indexItems, so that it can let us know when it is done.
                        self.indexItems(group:group, startingIndex:number)
                    }
                }
            } else {
                if let group = group {
                    // Leave dispatch group which we entered at top of this method.
                    group.leave()
                }
            }
        })
    }
    
    public func indexItems(group: DispatchGroup? = nil, startingIndex: Int) {
        // Index all items starting at the startingIndex
        
        // Use batching and client state for performance and correctness
        searchableIndex.beginBatch()
        
        // Find pictures starting at startingIndex
        // and retrieve their searchable items
        var itemsToIndex: [CSSearchableItem] = []
        for (elementIndex, picture) in pictures[startingIndex ..< pictures.count].enumerated() {
            
            itemsToIndex.append(picture.searchableItem())
            // If we've collected more than 5 send them to the CSSearchableIndex
            if itemsToIndex.count > 5 {
                
                searchableIndex.indexSearchableItems(itemsToIndex, completionHandler: nil)
                // State string records how many of our pictures have been indexed
                let stateString = String(elementIndex + startingIndex)
                
                searchableIndex.endBatch(withClientState: stateString.data(using:String.Encoding.utf8)!, completionHandler: { error in
                    if error == nil {
                        self.queue.async {
                            // Continue indexing where we left off
                            self.indexItems(group: group, startingIndex: elementIndex + startingIndex + 1)
                        }
                    } else {
                        if let group = group {
                            // Leave dispatch group which we entered before this method was called
                            group.leave()
                        }
                    }
                })
                return
            }
        }
        
        // We've made it to the last of our Pictures.
        searchableIndex.indexSearchableItems(itemsToIndex, completionHandler: nil)
        let stateString = String(pictures.count)
        searchableIndex.endBatch(withClientState: stateString.data(using:String.Encoding.utf8)!, completionHandler: nil)
        
        if let group = group {
            // Leave dispatch group which we entered before this method was called.
            group.leave()
        }

    }
    
    public func indexItems(identifiers: [String], group: DispatchGroup? = nil, startingIndex: Int = 0) {
        
        // Find pictures matching the identifiers after the starting index
        // and retrieve their searchable item.
        
        // We don't the begin batch and client state here, since the items to index
        // are requested by CoreSpotlight.
        
        var itemsToIndex: [CSSearchableItem] = []
        for (elementIndex, element) in pictures[startingIndex ..< pictures.count].enumerated() {
            if identifiers.contains(element.identifier) {
                
                itemsToIndex.append(element.searchableItem())
                
                // If we have more than 5 already, pass them along to the CSSearchableIndex.
                // Once that has completed, continue indexing where we left off.
                // By limiting the batch size, and waiting for one batch to finish before
                // sending the next, we make sure that we don't use too much memory for indexing.
                if itemsToIndex.count > 5 {
                    searchableIndex.indexSearchableItems(itemsToIndex, completionHandler: { error in
                        if error == nil {
                            self.queue.async {
                                // Continue indexing on background queue.
                                self.indexItems(identifiers:identifiers, group: group, startingIndex:startingIndex + elementIndex + 1)
                            }
                        } else {
                            // Giving up, leave the dispatch group.
                            if let group = group { group.leave(); }
                        }
                    })
                    
                    return
                }
            }
        }
        
        // Index the last items that we have
        // and finish by leaving the dispatch group
        searchableIndex.indexSearchableItems(itemsToIndex, completionHandler: nil)
        if let group = group {
            group.leave()
        }
    }

}

