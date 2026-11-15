public enum ReviewAPIError: Error, Equatable, Sendable {
    case unauthorized
    case offline
    case unavailable
    case forbidden(String)
    case conflict(String)
    case rejected(String)
}
