import Foundation
public import FactoryKit
public import Nuke

extension Container {
    public var imagePipeline: Factory<ImagePipeline> {
        self { ImagePipelines.make(caches: self.imageCaches()) }.singleton
    }

    public var imageCaches: Factory<ImageCaches> {
        self { ImageCaches() }.singleton
    }

    public var clipCache: Factory<ClipCache> {
        self {
            let configuration = URLSessionConfiguration.default
            // The cache's files are the only copy; URLCache would keep a second one.
            configuration.urlCache = nil
            return ClipCache(
                directory: .cachesDirectory.appending(path: "clips", directoryHint: .isDirectory),
                session: URLSession(configuration: configuration),
            )
        }
        .singleton
    }

    public var photoURLBuilder: Factory<PhotoURLBuilder> {
        self { PhotoURLBuilder(baseURL: .openSkateMapImages) }.singleton
    }

    public var imageLoader: Factory<ImageLoader> {
        self { .live(pipeline: self.imagePipeline()) }
            .singleton
            .onPreview { .placeholder }
    }

    public var thumbHashRenderer: Factory<ThumbHashRenderer> {
        self { ThumbHashRenderer() }.singleton
    }
}
