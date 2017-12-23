/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A view controller showing a collection of pictures
 This view controller exists to demonstrate restoring the app with different UI states
 from a Core Spotlight Item
*/

import UIKit
import CoreSpotlight
import PicturesFrameworkiOS

class GalleryViewController: UICollectionViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        // Create a searchable user activity to inform CoreSpotlight of how often the user vists this view
        let userActivity = NSUserActivity(activityType: galleryUserActivityIdentifier)
        let attributes = GalleryViewControllerCoreSpotlightSupport.attributeSet()
        
        attributes.relatedUniqueIdentifier = galleryUserActivityIdentifier

        userActivity.title = attributes.displayName
        userActivity.isEligibleForSearch = true
        userActivity.isEligibleForPublicIndexing = true
        userActivity.contentAttributeSet = attributes
        userActivity.needsSave = true
        userActivity.isEligibleForHandoff = false
        self.userActivity = userActivity
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return Datastore.sharedDatastore.count
    }

    func collectionView(_ collectionView: UICollectionView, layout
                        collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath
                        indexPath: NSIndexPath) -> CGSize {
        
        // Determine the size of an item in the collection view.
        let picture = Datastore.sharedDatastore.getPicture(atIndex:indexPath.row)
        
        var size = CGSize()
        let frameSize = collectionView.frame.size
        
        if let image = picture.image {
            size = image.size
            
            // Scale the image down if necessary while maintaining aspect ratio.
            if size.height > 300 {
                size.width *= (300 / size.height)
                size.height = 300
            }

            if size.width > frameSize.width {
                size.height *= (frameSize.width / size.width)
                size.width = frameSize.width
            }
        }
        return size
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // Get and set up a cell for an item in the collection view.
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "imageCell", for: indexPath)
        
        if let imageView = cell.contentView.subviews.first as? UIImageView {
            let picture = Datastore.sharedDatastore.getPicture(atIndex:indexPath.row)
            imageView.image = picture.image
        }
        
        return cell
    }
}

