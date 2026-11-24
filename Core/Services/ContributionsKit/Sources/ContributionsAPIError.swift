public enum ContributionsAPIError: Error, Equatable, Sendable {
    case unauthorized
    case offline
    case unavailable
    case missingPhotos([String])
    case missingClips([String])
    /// Refused for good. `message` is the server's, written for developers: it goes to the log, never on screen.
    case rejected(status: Int, message: String?)
}
