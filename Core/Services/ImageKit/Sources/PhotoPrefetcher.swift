public import CoreGraphics
import FactoryKit
import Foundation
import Nuke

/// Brings in photos and clips a screen will show next, at low priority and never over an expensive or constrained
/// network; each call replaces what the last one asked for, and everything stops when it goes.
@MainActor
public final class PhotoPrefetcher {

    // MARK: Properties

    // Resolved on the first prefetch, not when the view is made: the first resolution builds the pipeline.
    @LazyInjected(\.imagePipeline) private var pipeline
    @LazyInjected(\.photoURLBuilder) private var urls
    @LazyInjected(\.clipCache) private var clips

    private lazy var images = ImagePrefetcher(pipeline: pipeline)
    private let id = UUID()
    private var photoRequests = [ImageRequest]()
    private var clipURLs = [URL]()
    /// Clip wishes reach the cache in the order they were made, each after the one before.
    private var clipUpdate: Task<Void, Never>?

    // MARK: Lifecycle

    public init() { }

    isolated deinit {
        if !clipURLs.isEmpty {
            send([], to: clips)
        }
    }

    // MARK: Functions

    /// The variants of `photoKeys` at `size`, and the clips of `clipKeys`. Ask only for photos nothing loads yet: a load
    /// joins a prefetch already running for the same photo, network limits and all.
    public func prefetch(photoKeys: [String], clipKeys: [String], size: PhotoSize, scale: CGFloat) {
        let requests = photoKeys.compactMap { key in
            urls.url(for: key, size: size, scale: scale).map { ImageRequest.prefetchedPhoto($0, size: size) }
        }
        if requests.map(\.imageID) != photoRequests.map(\.imageID) {
            let kept = Set(requests.map(\.imageID))
            images.stopPrefetching(with: photoRequests.filter { !kept.contains($0.imageID) })
            images.startPrefetching(with: requests)
            photoRequests = requests
        }
        let clipURLs = clipKeys.compactMap(urls.clipURL(for:))
        if clipURLs != self.clipURLs {
            self.clipURLs = clipURLs
            send(clipURLs, to: clips)
        }
    }

    public func cancel() {
        guard !photoRequests.isEmpty || !clipURLs.isEmpty else {
            return
        }
        images.stopPrefetching()
        photoRequests = []
        clipURLs = []
        send([], to: clips)
    }

    private func send(_ urls: [URL], to cache: ClipCache) {
        clipUpdate = Task { @concurrent [clipUpdate, id] in
            await clipUpdate?.value
            await cache.prefetch(urls, for: id)
        }
    }
}
