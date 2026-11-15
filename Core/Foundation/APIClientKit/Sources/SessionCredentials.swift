// MARK: - SessionCredentials

public struct SessionCredentials: Sendable {
    public var token: @Sendable () async -> String?
    public var refused: @Sendable (_ token: String) async -> Void
    /// Analytics off: requests say `DNT: 1`, so the server sends nothing about the person.
    public var doNotTrack: @Sendable () -> Bool
    public var accountID: @MainActor @Sendable () -> String?

    public init(token: @escaping @Sendable () async -> String?,
                refused: @escaping @Sendable (_ token: String) async -> Void,
                doNotTrack: @escaping @Sendable () -> Bool = { false },
                accountID: @escaping @MainActor @Sendable () -> String? = { nil }) {
        self.token = token
        self.refused = refused
        self.doNotTrack = doNotTrack
        self.accountID = accountID
    }
}

extension SessionCredentials {
    public static let signedOut = SessionCredentials(token: { nil }, refused: { _ in })

    public static func constant(_ token: String) -> SessionCredentials {
        SessionCredentials(token: { token }, refused: { _ in })
    }
}
