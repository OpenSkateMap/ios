import APIClientKit

// MARK: - PhotoUploadError

public enum PhotoUploadError: Error, Equatable, Sendable {
    case unauthorized
    case offline
    case unavailable
    case rejected(String)
    /// A status the API doesn't document; callers say it in their own words.
    case refused(status: Int)
}

extension PhotoUploadError {
    init(_ failure: APIFailure) {
        switch failure.status {
        case 401: self = .unauthorized
        case 403, 404, 409, 422: self = failure.message.map(PhotoUploadError.rejected) ?? .refused(status: failure.status)
        case 429, 500...: self = .unavailable
        default: self = .refused(status: failure.status)
        }
    }
}
