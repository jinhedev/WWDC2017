/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The application delegate
*/

import UIKit
import CoreSpotlight
import Dispatch
import PicturesFrameworkiOS

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    override init() {
        super.init()
        let indexDelegate = PicturesIndexDelegate()
        CSSearchableIndex.default().indexDelegate = indexDelegate
        indexDelegate.updateSearchableItems()
    }
    
    // Update app state based on the userActivity.
    // Restores the application to either the PictureListViewController, GalleryViewController,
    // or a DetailViewController of a particular Picture.
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([Any]?) -> Void) -> Bool {
        
        if userActivity.activityType == CSSearchableItemActionType {
            // Called when the user punches out to a an CoreSpotligt item
            guard let confirmedUserInfo = userActivity.userInfo,
                let uniqueIdentifier = confirmedUserInfo[CSSearchableItemActivityIdentifier] as? String else {
                    return false
            }
            
            if uniqueIdentifier == pictureListUserActivityIdentifier {
                activatePictureListViewController(query: "")
            } else if uniqueIdentifier == galleryUserActivityIdentifier {
                activateGalleryViewController(itemIdentifier: nil)
            } else {
                activatePictureListViewController(itemIdentifier:uniqueIdentifier)
            }
            
            return true
        } else if userActivity.activityType == pictureListUserActivityIdentifier {
            // Called for a searchable user activity
            activatePictureListViewController(query:"")
        } else if userActivity.activityType == galleryUserActivityIdentifier {
            // Called for a searchable user activity
            activateGalleryViewController(itemIdentifier:nil)
        } else if userActivity.activityType == CSQueryContinuationActionType {
            // Called for a Search in App
            
            guard let confirmedUserInfo = userActivity.userInfo,
                let searchQuery = confirmedUserInfo[CSSearchQueryString] as? String else {
                    return false
            }
            
            activatePictureListViewController(query:searchQuery)
            return true
        }
        
        return false
    }

}
