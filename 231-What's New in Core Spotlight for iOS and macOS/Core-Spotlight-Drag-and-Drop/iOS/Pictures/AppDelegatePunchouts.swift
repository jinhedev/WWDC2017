/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The application delegate extension that handles navigating to the correct app state when launched via spotlight.
*/

import Foundation
import UIKit
import PicturesFrameworkiOS

// Takes the app to various states based on NSUserActivity.
extension AppDelegate {
    
    // Take the app to the PictureListViewController, filling in the search bar with a query.
    // An empty string can be used for no query.
    func activatePictureListViewController(query: String) {
        
        guard let confirmedWindow = window,
            let tabBarController = confirmedWindow.rootViewController as? UITabBarController,
            let navigationController = tabBarController.viewControllers?.first as? UINavigationController,
            let pictureListViewController = navigationController.viewControllers.first as? PictureListViewController,
            let searchBar = pictureListViewController.searchBar else {
            return
        }
        
        tabBarController.selectedViewController = navigationController
        pictureListViewController.loadViewIfNeeded()
        
        // Fill in the search query.
        searchBar.text = query
        if let searchDelegate = searchBar.delegate {
            searchDelegate.searchBar?(searchBar, textDidChange: query)
        }
        
        // Pops the app back to the list view if we were in the detail view.
        if pictureListViewController != navigationController.topViewController {
            navigationController.popToViewController(pictureListViewController, animated: false)
        }
    }
    
    func activatePictureListViewController(itemIdentifier: String) {
        
        // Verifying the view heirarchy.
        guard let confirmedWindow = window,
            let tabBarController = confirmedWindow.rootViewController as? UITabBarController,
            let tabBarViewControllers = tabBarController.viewControllers,
            let navigationController = tabBarViewControllers.first as? UINavigationController,
            let pictureListViewController = navigationController.viewControllers.first as? PictureListViewController else {
                return
        }
        
        // Set the current view controller to be the PictureListViewController.
        tabBarController.selectedViewController = navigationController
        pictureListViewController.loadViewIfNeeded()
        pictureListViewController.searchBar?.text = ""
        
        // If we found a picture based on the itemIdentifier,
        // also show the DetailViewController matching that picture.
        guard let foundPicture = Datastore.sharedDatastore.picture(identifier:itemIdentifier) else {
            navigationController.setViewControllers([pictureListViewController], animated: false)
            return
        }
                    
        let detailViewController = DetailViewController(picture: foundPicture)
        navigationController.setViewControllers([pictureListViewController, detailViewController], animated: false)
    }
    
    func activateGalleryViewController(itemIdentifier: String?) {
        
        // Confirm view heirarchy.
        guard let confirmedWindow = window,
            let tabBarController = confirmedWindow.rootViewController as? UITabBarController,
            let tabBarViewControllers = tabBarController.viewControllers,
            let vc = tabBarViewControllers[1] as? GalleryViewController else {
            return
        }
        
        // Display the gallery.
        tabBarController.selectedViewController = vc
    }
    
}

