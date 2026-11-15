/// Runs when the server publishes a sent spot or edit at once (an admin's, or a private spot), so the map shows it
/// without waiting for the next sync: private spots come with collections, public ones with the spot sync.
public struct PublishedSpotHandler: Sendable {
    public enum Visibility: Equatable, Sendable {
        case `public`
        /// In one of the account's private collections.
        case `private`
    }

    public static let none = PublishedSpotHandler { _ in }

    public var run: @Sendable (Visibility) async -> Void

    public init(run: @escaping @Sendable (Visibility) async -> Void) {
        self.run = run
    }
}
