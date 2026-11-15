public import APIClientKit
public import Foundation
public import OpenAPIRuntime

// MARK: - PhotoUploadManager

public struct PhotoUploadManager: Sendable {
    public var prepare: @Sendable (_ imageData: Data) async throws -> PreparedPhoto
    public var upload: @Sendable (_ photoID: String, _ jpeg: Data) async throws -> Void

    public init(prepare: @escaping @Sendable (_ imageData: Data) async throws -> PreparedPhoto,
                upload: @escaping @Sendable (_ photoID: String, _ jpeg: Data) async throws -> Void) {
        self.prepare = prepare
        self.upload = upload
    }
}

extension PhotoUploadManager {
    public static func live(credentials: SessionCredentials,
                            makeClient: @escaping @Sendable ([any ClientMiddleware]) -> Client) -> PhotoUploadManager {
        PhotoUploadManager(
            prepare: { try await PhotoPreparation.prepare($0) },
            upload: { photoID, jpeg in
                _ = try await credentials.authorized(
                    makeClient,
                    signedOut: PhotoUploadError.unauthorized,
                    offline: PhotoUploadError.offline,
                    failure: PhotoUploadError.init,
                ) {
                    try await $0.uploadPhoto(path: .init(photoId: photoID), body: .jpeg(HTTPBody(jpeg))).ok
                }
            },
        )
    }

    public static let preview = PhotoUploadManager(
        prepare: { try await PhotoPreparation.prepare($0) },
        upload: { _, _ in },
    )
}
