public import Foundation
public import Nuke
public import UIKit

// MARK: - ImageLoader

public struct ImageLoader: Sendable {
    public var image: @Sendable (_ url: URL, _ size: CGSize) async throws -> UIImage
    /// One of our variants (`PhotoURLBuilder`) as the CDN sized it: no resize or re-encode, the cache entry `PhotoLoader` uses.
    public var photo: @Sendable (_ url: URL, _ size: PhotoSize) async throws -> UIImage

    public init(image: @escaping @Sendable (_ url: URL, _ size: CGSize) async throws -> UIImage,
                photo: @escaping @Sendable (_ url: URL, _ size: PhotoSize) async throws -> UIImage) {
        self.image = image
        self.photo = photo
    }
}

extension ImageLoader {
    public static let placeholder = ImageLoader(
        image: { _, _ in throw CancellationError() },
        photo: { _, _ in throw CancellationError() },
    )

    public static func live(pipeline: ImagePipeline) -> ImageLoader {
        ImageLoader(
            image: { url, size in
                let request = ImageRequest(
                    url: url,
                    processors: [.resize(size: size, contentMode: .aspectFill, upscale: false)],
                    userInfo: [ImagePipelines.useCase: ImagePipelines.UseCase.photo.rawValue],
                )
                return try await pipeline.image(for: request)
            },
            photo: { url, size in
                try await pipeline.image(for: ImageRequest.photo(url, size: size))
            },
        )
    }
}

// MARK: - ImageRequest

extension ImageRequest {
    static func photo(_ url: URL, size: PhotoSize) -> ImageRequest {
        ImageRequest(url: url, userInfo: [ImagePipelines.useCase: (size == .pin ? ImagePipelines.UseCase.pin : .photo).rawValue])
    }
}
