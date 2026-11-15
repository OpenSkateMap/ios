public enum SignedOutNotice: Equatable, Sendable {
    case appleSignInFailed
    case offline
    case signInRejected
    case serverUnavailable
    case sessionExpired
    case accountDisabled
    case accountDeleted
}
