public struct SignedInAccount: Codable, Equatable, Sendable {
    public var token: String
    public var account: Account
    /// Apple's id for the person; nil for sessions stored before it was kept.
    public var appleUserID: String?

    public init(token: String, account: Account, appleUserID: String? = nil) {
        self.token = token
        self.account = account
        self.appleUserID = appleUserID
    }
}
