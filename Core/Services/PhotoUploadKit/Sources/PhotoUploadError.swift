import APIClientKit

// MARK: - PhotoUploadError

public enum PhotoUploadError: Error, Equatable, Sendable {
    case unauthorized
    case offline
    case unavailable
    /// Refused for good. `message` is the server's, written for developers, and only for a status the API documents.
    case rejected(status: Int, message: String?)
}

extension PhotoUploadError {
    init(_ failure: APIFailure) {
        switch failure.status {
        case 401: self = .unauthorized
        case 403, 404, 409, 422: self = .rejected(status: failure.status, message: failure.message)
        case 429, 500...: self = .unavailable
        default: self = .rejected(status: failure.status, message: nil)
        }
    }
}
