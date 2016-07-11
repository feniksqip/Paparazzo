import Foundation
import ImageIO
import MobileCoreServices

struct UrlImageSource: ImageSource {

    private let url: NSURL

    init(url: NSURL) {
        self.url = url
    }

    // MARK: - ImageSource
    
    func writeImageToUrl(url: NSURL, completion: Bool -> ()) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { [url] in
            
            var success = false
            
            let source = CGImageSourceCreateWithURL(url, nil)
            // TODO: тип картинки определять по расширению целевого файла
            let destination = CGImageDestinationCreateWithURL(url, kUTTypeJPEG, 1, nil)
            
            if let source = source, destination = destination {
                CGImageDestinationAddImageFromSource(destination, source, 0, nil)
                success = CGImageDestinationFinalize(destination)
            }
            
            dispatch_async(dispatch_get_main_queue()) {
                completion(success)
            }
        }
    }

    func fullResolutionImage<T: InitializableWithCGImage>(completion: (T?) -> ()) {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { [url] in
         
            let source = CGImageSourceCreateWithURL(url, nil)
            let options = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) } as? NSDictionary
            
            
            debugPrint("orientation == \(options?[kCGImagePropertyOrientation as String])")

            let cgImage = source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, options) }
            
            dispatch_async(dispatch_get_main_queue()) {
                completion(cgImage.flatMap { T(CGImage: $0) })
            }
        }
    }

    func imageFittingSize<T: InitializableWithCGImage>(size: CGSize, contentMode: ImageContentMode, completion: (T?) -> ()) {

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0)) { [url] in

            let source = CGImageSourceCreateWithURL(url, nil)

            let options: [NSString: NSObject] = [
                kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceCreateThumbnailFromImageAlways: true
            ]

            let cgImage = source.flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options) }

            dispatch_async(dispatch_get_main_queue()) {
                completion(cgImage.flatMap { T(CGImage: $0) })
            }
        }
    }
}