import Foundation
public import Nuke

// MARK: - ImagePipelines

/// One pipeline, so requests for the same photo dedupe across uses.
public enum ImagePipelines {

    // MARK: Types

    public enum UseCase: String, Sendable {
        case pin
        case photo
    }

    // MARK: Static Properties

    public static let useCase: ImageRequest.UserInfoKey = "openskatemap.useCase"

    // MARK: Static Functions

    public static func make(caches: ImageCaches) -> ImagePipeline {
        var configuration = ImagePipeline.Configuration()
        // As `withDataCache` sets it up: the disk cache stands in for the URL cache.
        let session = URLSessionConfiguration.default
        session.urlCache = nil
        configuration.dataLoader = DataLoader(configuration: session)
        configuration.dataCache = caches.disk
        configuration.dataCachePolicy = .automatic
        // Nuke decodes thumbnails on this queue one at a time by default; three leaves headroom for MapKit and the main thread.
        configuration.imageDecodingQueue.maxConcurrentOperationCount = 3
        configuration.imageDecompressingQueue.maxConcurrentOperationCount = 2
        #if DEBUG
        ImagePipeline.Configuration.isSignpostLoggingEnabled = true
        #endif
        return ImagePipeline(configuration: configuration, delegate: UseCaseCaches(caches: caches))
    }
}

// MARK: - ImageCaches

/// The pipeline's caches: memory per use case, so map thumbnails don't evict covers, and the disk.
public final class ImageCaches: Sendable {

    // MARK: Properties

    let pins = ImageCache(costLimit: 64 << 20)
    let photos = ImageCache(costLimit: 256 << 20)
    let disk: DataCache?

    // MARK: Lifecycle

    public init() {
        disk = try? DataCache(name: "com.ertembiyik.openskatemap.images")
        disk?.sizeLimit = 400 << 20
    }

    // MARK: Functions

    public func removeAll() {
        pins.removeAll()
        photos.removeAll()
        disk?.removeAll()
    }
}

// MARK: - UseCaseCaches

private final class UseCaseCaches: ImagePipeline.Delegate {

    // MARK: Properties

    private let caches: ImageCaches

    // MARK: Lifecycle

    init(caches: ImageCaches) {
        self.caches = caches
    }

    // MARK: Functions

    func imageCache(for request: ImageRequest, pipeline _: ImagePipeline) -> (any ImageCaching)? {
        let useCase = (request.userInfo[ImagePipelines.useCase] as? String).flatMap(ImagePipelines.UseCase.init)
        return useCase == .pin ? caches.pins : caches.photos
    }
}
