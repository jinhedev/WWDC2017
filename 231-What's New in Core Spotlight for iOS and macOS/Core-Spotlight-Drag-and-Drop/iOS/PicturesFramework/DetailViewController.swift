/*
See LICENSE folder for this sample’s licensing information.

Abstract:
View controller for the preview content
*/

import UIKit

public class DetailViewController: UIViewController {
    
    @IBOutlet public weak var imageView: UIImageView?
    @IBOutlet public weak var titleField: UILabel?
    @IBOutlet public weak var descriptionField: UITextView?
    @IBOutlet public weak var ratingsField: UILabel?
    
    var formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat="yyyyMMdd"
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMdd")
        return formatter
    }()
        
    public var picture: Picture? {
        
        didSet {
            
            var valueDidChange = false
            if oldValue != nil {
               valueDidChange = oldValue!.isEqual(picture)
            } else if picture != nil {
                valueDidChange = true
            }
            
            if !valueDidChange {
                // When the user is switches to a different picture,
                // update the user activity so that the CoreSpotlight index tracks usage
                guard let confirmedUserActivity = userActivity else {
                    return
                }
                
                guard let confirmedPicture = picture else {
                    confirmedUserActivity.title = nil
                    confirmedUserActivity.userInfo = nil
                    return
                }
                
                confirmedUserActivity.title = confirmedPicture.name
                let attributeSet = confirmedPicture.searchableItemAttributes()
                attributeSet.relatedUniqueIdentifier = confirmedPicture.identifier
                confirmedUserActivity.contentAttributeSet = attributeSet
                confirmedUserActivity.userInfo = ["pictureIdentifier": confirmedPicture.identifier]
                confirmedUserActivity.needsSave = true
                
            }
        }
    }
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init?(coder aDecoder: NSCoder) {
        let bundle = Bundle(for: Datastore.self)
        super.init(nibName: "DetailViewController", bundle: bundle)
        self.edgesForExtendedLayout = UIRectEdge()
    }
    
    // Create a DetailViewController and populate it with information from a Picture object.
    public convenience init(picture: Picture) {
        // Load the nib from the framework.
        let bundle = Bundle(for: Datastore.self)
        self.init(nibName: "DetailViewController", bundle: bundle)
        self.edgesForExtendedLayout = UIRectEdge()
        
        self.loadViewIfNeeded()
        
        updateWithPicture(picture: picture)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up a searchable user activity for looking at a picture in the detail view.
        let confirmedUserActivity = NSUserActivity(activityType: "com.example.apple-samplecode.Pictures.detail")
        confirmedUserActivity.isEligibleForSearch = true
        confirmedUserActivity.isEligibleForPublicIndexing = false
        confirmedUserActivity.isEligibleForHandoff = false
        userActivity = confirmedUserActivity
        
        updateWithPicture(picture: self.picture)
    }
    
    func updateWithPicture(picture: Picture?) {
        // Fill in IBOutlets with picture information.
        guard let confirmedPicture = picture,
            let confirmedImageView = self.imageView,
            let confirmedTitleField = self.titleField,
            let confirmedDescriptionField = self.descriptionField,
            let confirmedRatingsField = self.ratingsField else {
            return
        }
        
        confirmedImageView.image = confirmedPicture.image
        confirmedTitleField.text = confirmedPicture.name
        confirmedDescriptionField.text = confirmedPicture.description
        confirmedRatingsField.text = confirmedPicture.ratingString()
    }

}
