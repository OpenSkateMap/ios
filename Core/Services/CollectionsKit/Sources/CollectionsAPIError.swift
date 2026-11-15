import APIClientKit

public enum CollectionsAPIError: Error, Equatable, Sendable {
    case unauthorized
    case notFound
    case forbidden
    case refused(message: String?)
    case unavailable
    case offline

    init(_ failure: APIFailure) {
        switch failure.status {
        case 401: self = .unauthorized
        case 403: self = .forbidden
        case 404: self = .notFound
        case 409, 422: self = .refused(message: failure.message)
        case 429: self = .unavailable
        case 400..<500: self = .refused(message: nil)
        default: self = .unavailable
        }
    }
}
