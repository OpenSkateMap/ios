public enum PeopleAPIError: Error, Equatable, Sendable {
    case unauthorized
    case offline
    case unavailable
    case notFound
    case usernameUnavailable
    case rejected(String)
}
