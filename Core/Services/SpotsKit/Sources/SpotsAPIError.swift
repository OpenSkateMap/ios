public enum SpotsAPIError: Error, Equatable, Sendable {
    case unauthorized
    case rejected
    case unavailable
    case offline
}
