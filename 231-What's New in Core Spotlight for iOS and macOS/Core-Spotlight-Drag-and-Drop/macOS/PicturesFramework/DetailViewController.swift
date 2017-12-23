/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller for the preview content
*/

import Cocoa

public class DetailViewController: NSViewController {
    
    @IBOutlet public weak var imageView: NSImageView?
    @IBOutlet public weak var titleField: NSTextField?
    @IBOutlet public weak var ratingsField: NSTextField?
    @IBOutlet public weak var descriptionField: NSTextField?
    
    // Create and populate a DetailViewController with a Picture object
    public convenience init(picture: Picture) {
        
        // Retrieve the nib.
        let bundle = Bundle(for: Datastore.self)
        self.init(nibName: NSNib.Name(rawValue: "DetailViewController"), bundle: bundle)
        
        // Force the view to load from nib by accessing view property.
        _ = self.view
        
        // Make sure that all the IBOutlets are successfully initialized.
        guard let titleField = self.titleField,
            let imageView = self.imageView,
            let ratingsField = self.ratingsField,
            let descriptionField = self.descriptionField else {
            return
        }
        
        // Fill in the IBOutlets with data from the Picture object.
        titleField.stringValue = picture.name
        imageView.image = picture.image
        ratingsField.stringValue = picture.ratingString()
        
        // Description is optional, don't fill it in if there isn't any.
        guard let pictureDescription = picture.description else {
            return
        }
        
        descriptionField.stringValue = pictureDescription
        
    }
    
}
