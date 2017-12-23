/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Contains information about each picture such as description, title, rating, etc.
*/

import Foundation
import MapKit
import CoreSpotlight
import QuartzCore
import CoreGraphics
import ImageIO

#if os(iOS)
import UIKit
import MobileCoreServices
#else
import AppKit
#endif

#if os(iOS)
public typealias PictureCrossPlatformImage = UIImage
#else
public typealias PictureCrossPlatformImage = NSImage
#endif

public class Picture  {
    
    static let path: String = Datastore.thumbnailPath
    
    init?(imageIdentifier: String,
          imageName: String,
          imageRating: Float,
          imageDescription: String?,
          imageDate: Date?) {
        
        identifier = imageIdentifier
        name = imageName
        rating = imageRating
        description = imageDescription
        date = imageDate
        thumbnailURL = URL(fileURLWithPath: Picture.path + "/" + (self.identifier + ".png"))
        
    }
    
    // Used to init a Picture from a plist.
    convenience init?(dictionary: [String:AnyObject]) {
        
        guard let imageIdentifier = dictionary["file"] as? String,
            let name = dictionary["name"] as? String else {
                return nil
        }
        
        let description = dictionary["description"] as? String
        let date = dictionary["date"] as? Date
        
        var rating: Float = 0
        if let ratingNumber = dictionary["rating"] as? NSNumber {
            rating = ratingNumber.floatValue
        }
        
        self.init(imageIdentifier:imageIdentifier, imageName:name, imageRating:rating, imageDescription:description, imageDate:date)
    }
    
    public func isEqual(_ object: Any?) -> Bool {
        if let object = object as? Picture {
            return identifier == object.identifier
        } else {
            return false
        }
    }
    
    // Provide the core spotlight item attributes for a Picture.
    public func searchableItemAttributes() -> CSSearchableItemAttributeSet {
        let attributes: CSSearchableItemAttributeSet = CSSearchableItemAttributeSet(itemContentType: kUTTypeImage as String)
        attributes.displayName = name
        attributes.rating = rating as NSNumber?
        attributes.namedLocation = "Cupertino"
        attributes.thumbnailURL = thumbnailURL
        attributes.contentDescription = description
        attributes.contentCreationDate = date
        
        // Advertise the draggable type identifiers for your content.
        // If the same type is advertised as for both data and file provision,
        // the data version will be preferred by Spotlight.
        attributes.providerDataTypeIdentifiers = [kUTTypeUTF8PlainText as String]
        attributes.providerFileTypeIdentifiers = [kUTTypeImage as String]
        
        return attributes
    }
    
    // Create a core spotlight item for the picture.
    func searchableItem() -> CSSearchableItem {
        let attributes = searchableItemAttributes()
        let item = CSSearchableItem(uniqueIdentifier: identifier,
                                    domainIdentifier: "com.example.apple-samplecode.Pictures.images", attributeSet: attributes)
        return item
    }
    
    // Loads the NSImage or UIImage from the file URL.
    // This can retrieve either the full size image or a thumbnail.
    
    func loadImage(isThumbnail: Bool) -> PictureCrossPlatformImage? {
        
        #if os(iOS)
            let scale = UIScreen.main.scale
            var image: UIImage?
        #else
            let scale = NSScreen.main!.backingScaleFactor
            var image: NSImage?
        #endif
        
        let frameworkBundle = Bundle(for:Datastore.self)
        guard let imageURL = frameworkBundle.url(forResource:identifier, withExtension:"jpg"),
            let imageSource = CGImageSourceCreateWithURL((imageURL as CFURL), nil) else
        {
            return nil
        }
        
        if isThumbnail {
            let options: [NSString: NSObject] = [
                kCGImageSourceThumbnailMaxPixelSize: NSNumber(value: Float(scale * CGFloat(80.0))),
                kCGImageSourceCreateThumbnailFromImageAlways: NSNumber(value:true)
            ]
            
            #if os(iOS)
                image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary?).flatMap { UIImage(cgImage: $0) }
            #else
                let cgimage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary?)
                image = cgimage.flatMap {
                    NSImage(cgImage: $0, size:NSSize(width: $0.width, height: $0.height))
                }
            #endif
            
            guard let confirmedImage = image else {
                return nil
            }
            
            #if os(iOS)
                guard let pngRepresentation = UIImagePNGRepresentation(confirmedImage) else {
                    // We failed to write the thumbnail for indexing but at least we can return the image.
                    return image
                }
                let imageData = NSData(data:pngRepresentation)
            #else
                guard let confirmedCGImage = cgimage,
                    let imageData = pngDataFromCGImage(image: confirmedCGImage) else {
                    // We failed to write the thumbnail for indexing but at least we can return the image.
                    return image
                }
            #endif
            
            let fullPath = Picture.path + "/" + (identifier + ".png")
            
            // Store thumbnail data for the core spotlight index.
            imageData.write(toFile:fullPath, atomically: true)
            
        } else {
            #if os(iOS)
                image = UIImage(cgImage: CGImageSourceCreateImageAtIndex(imageSource, 0, nil)!)
            #else
                guard let fullCGImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                    return nil
                }
                image = NSImage(cgImage: fullCGImage, size:NSSize(width:fullCGImage.width, height:fullCGImage.height))
            #endif
        }
        
        return image
    }

    #if os(macOS)
    
    // Produces png data from a CGImage.
    // Necessary since by default NSImage provides tiff data and it would be nice to keep the thumbnail format consistent across iOS and macOS.
    func pngDataFromCGImage(image: CGImage) -> NSData? {
            
        let imageRep = NSBitmapImageRep(cgImage:image)
        imageRep.size = NSSize(width: image.width, height: image.height)
        
        guard let data = imageRep.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else {
            return nil
        }
        
        return NSData(data: data)
    }
    #endif
    
    // Turns the rating into a string of stars for display.
    public func ratingString() -> String {
        
        let rating = self.rating
        let roundedRating = Int(rating)
        var stringRating = ""
        
        guard roundedRating > 0 else {
            return ""
        }
        
        for _ in 1 ... roundedRating {
            stringRating.append("⭐️")
        }
        
        return stringRating
    }
 
    public var identifier: String
    public var name: String
    public var thumbnailURL: URL?
    public var date: Date?
    public var location: CLLocation?
    public var rating: Float = 0
    public var description: String?
    
    lazy public var image: PictureCrossPlatformImage? = self.loadImage(isThumbnail:false)
    lazy public var thumbnail: PictureCrossPlatformImage?  = self.loadImage(isThumbnail:true)
    
}
