import FactoryKit
import Nuke
public import UIKit

@MainActor
public final class PhotoLoader {

    // MARK: Properties

    // Resolved on the first photo, not when the view is made: the first resolution builds the pipeline.
    @LazyInjected(\.imagePipeline) private var pipeline
    @LazyInjected(\.photoURLBuilder) private var urls
    @LazyInjected(\.thumbHashRenderer) private var renderer

    private var shown: String?
    private var loading: Task<Void, Never>?

    // MARK: Lifecycle

    public init() { }

    isolated deinit {
        loading?.cancel()
    }

    // MARK: Functions

    public func cancel() {
        loading?.cancel()
        loading = nil
        shown = nil
    }

    public func show(key: String?,
                     thumbhash: String?,
                     size: PhotoSize,
                     scale: CGFloat,
                     placeholder: UIImage? = nil,
                     in imageView: UIImageView) {
        let identity = [key ?? "", thumbhash ?? "", "\(size)", "\(scale)"].joined(separator: "|")
        guard identity != shown else {
            return
        }
        shown = identity
        loading?.cancel()
        let request = key.flatMap { urls.url(for: $0, size: size, scale: scale) }.map { ImageRequest.photo($0, size: size) }
        if let request, let cached = pipeline.cache[request] {
            imageView.image = cached.image
            return
        }
        imageView.image = placeholder
        guard request != nil || thumbhash != nil else {
            return
        }
        loading = Task { [weak imageView, pipeline, renderer] in
            if placeholder == nil, let thumbhash, let image = await renderer.image(base64: thumbhash), !Task.isCancelled {
                imageView?.image = image
            }
            guard let request, let image = try? await pipeline.image(for: request), !Task.isCancelled else {
                return
            }
            imageView?.image = image
        }
    }
}
