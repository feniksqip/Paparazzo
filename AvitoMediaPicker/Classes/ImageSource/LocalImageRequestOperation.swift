import Foundation
import ImageIO
import MobileCoreServices

/// Operation for requesting images stored in a local file.
final class LocalImageRequestOperation<T: InitializableWithCGImage>: Operation, ImageRequestIdentifiable {
    
    let id: ImageRequestId
    
    private let path: String
    private let options: ImageRequestOptions
    private let resultHandler: (ImageRequestResult<T>) -> ()
    private let callbackQueue: DispatchQueue
    
    // Можно сделать failable/throwing init, который будет возвращать nil/кидать исключение, если url не файловый,
    // но пока не вижу в этом особой необходимости
    init(id: ImageRequestId,
         path: String,
         options: ImageRequestOptions,
         resultHandler: @escaping (ImageRequestResult<T>) -> (),
         callbackQueue: DispatchQueue = .main)
    {
        self.id = id
        self.path = path
        self.options = options
        self.resultHandler = resultHandler
        self.callbackQueue = callbackQueue
    }
    
    override func main() {
        switch options.size {
        case .FullResolution:
            getFullResolutionImage()
        case .FillSize(let size):
            getImage(resizedTo: size)
        case .FitSize(let size):
            getImage(resizedTo: size)
        }
    }
    
    // MARK: - Private
    
    private func getFullResolutionImage() {
        
        guard !isCancelled else { return }
        let url = NSURL(fileURLWithPath: path)
        let source = CGImageSourceCreateWithURL(url, nil)
        
        let options = source.flatMap { CGImageSourceCopyPropertiesAtIndex($0, 0, nil) } as Dictionary?
        let orientation = options?[kCGImagePropertyOrientation] as? Int
        
        guard !isCancelled else { return }
        var cgImage = source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, options) }
        
        if let exifOrientation = orientation.flatMap({ ExifOrientation(rawValue: $0) }) {
            guard !isCancelled else { return }
            cgImage = cgImage?.imageFixedForOrientation(exifOrientation)
        }
        
        guard !isCancelled else { return }
        callbackQueue.async { [resultHandler, id] in
            resultHandler(ImageRequestResult(
                image: cgImage.flatMap { T(CGImage: $0) },
                degraded: false,
                requestId: id
            ))
        }
    }
    
    private func getImage(resizedTo size: CGSize) {
        
        guard !isCancelled else { return }
        let url = NSURL(fileURLWithPath: path)
        let source = CGImageSourceCreateWithURL(url, nil)
        
        let options: [NSString: NSObject] = [
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true
        ]
        
        guard !isCancelled else { return }
        let cgImage = source.flatMap { CGImageSourceCreateThumbnailAtIndex($0, 0, options) }
        
        guard !isCancelled else { return }
        callbackQueue.async { [resultHandler, id] in
            resultHandler(ImageRequestResult(
                image: cgImage.flatMap { T(CGImage: $0) },
                degraded: false,
                requestId: id
            ))
        }
    }
}

protocol ImageRequestIdentifiable {
    var id: ImageRequestId { get }
}
