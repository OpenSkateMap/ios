public import SQLiteData

/// What the person did with a photo the library scan matched to a spot.
public enum LibraryMatchState: String, CaseIterable, Codable, Sendable, QueryBindable {
    /// Waiting on the Contribute tab.
    case new
    /// Not This One: never shown again, and a later scan never brings that spot and day back.
    case skipped
    /// Sent with an edit of the spot.
    case used
}
