/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller displayed by Spotlight
*/

import UIKit
import QuickLook
import PicturesFrameworkiOS

class PreviewViewController: UIViewController, QLPreviewingController {

    func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping QLPreviewItemLoadingBlock) {
        // Perform any setup necessary in order to prepare the view.
        // Find data matching the identifier, populate view based on data.
        if let foundPicture = Datastore.sharedDatastore.picture(identifier:identifier) {
            let detailViewController = DetailViewController(picture: foundPicture)
            self.present(detailViewController, animated: false, completion: nil)
        }
        
        // Call the completion handler so Quick Look knows that the preview is fully loaded.
        // Quick Look will display a loading spinner while the completion handler is not called.
        handler(nil)
    }
    
}
