import APIClientKit
import Foundation
import OpenAPIRuntime
import PhotoUploadKit

func authorized<Output>(_ credentials: SessionCredentials,
                        _ makeClient: @Sendable ([any ClientMiddleware]) -> Client,
                        _ call: (Client) async throws -> Output) async throws -> Output {
    try await credentials.authorized(
        makeClient,
        signedOut: ContributionsAPIError.unauthorized,
        offline: ContributionsAPIError.offline,
        failure: ContributionsAPIError.init,
        call,
    )
}

extension ContributionsAPIError {
    init(_ failure: APIFailure) {
        switch failure.status {
        case 401: self = .unauthorized
        case 422 where !failure.missing("missingPhotos").isEmpty: self = .missingPhotos(failure.missing("missingPhotos"))
        case 422 where !failure.missing("missingClips").isEmpty: self = .missingClips(failure.missing("missingClips"))
        case 403, 404, 409, 422: self = .rejected(failure.message ?? ContributionsKitStrings.ApiError.refused(failure.status))
        case 429, 500...: self = .unavailable
        default: self = .rejected(ContributionsKitStrings.ApiError.refused(failure.status))
        }
    }

    init(_ upload: PhotoUploadError) {
        switch upload {
        case .unauthorized: self = .unauthorized
        case .offline: self = .offline
        case .unavailable: self = .unavailable
        case .rejected(let message): self = .rejected(message)
        case .refused(let status): self.init(APIFailure(status: status))
        }
    }
}

extension APIFailure {
    /// The uploads a submission names that the server hasn't received (`details.missingPhotos` or
    /// `details.missingClips` on a 422).
    fileprivate func missing(_ key: String) -> [String] {
        (error?.details?.additionalProperties[key]?.value as? [any Sendable?])?.compactMap { $0 as? String } ?? []
    }
}
