/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller displayed by Spotlight
*/

import Cocoa
import Quartz
import PicturesFrameworkMacOS

class PreviewViewController: NSViewController, QLPreviewingController {
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }

    func preparePreviewOfSearchableItem(withIdentifier identifier: String,
                                        queryString: String,
                                        completionHandler: @escaping QLPreviewItemLoadingBlock) {
        // Perform any setup necessary in order to prepare the view.
        
        // Find data matching the identifier, populate view based on data
        if let foundPicture = Datastore.sharedDatastore.picture(identifier:identifier) {
            let detailViewController = DetailViewController(picture: foundPicture)
            self.view.addSubview(detailViewController.view)
        }
        
        // Call the completion handler so Quick Look knows that the preview is fully loaded.
        // Quick Look will display a loading spinner while the completion handler is not called.
        completionHandler(nil)
    }

}
