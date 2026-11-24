public enum ContributionsAPIError: Error, Equatable, Sendable {
    case unauthorized
    case offline
    case unavailable
    case missingPhotos([String])
    case missingClips([String])
    case rejected(String)
}
