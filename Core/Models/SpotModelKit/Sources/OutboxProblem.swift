public import SQLiteData

/// What kept a `failed` outbox entry from going out. A kind, never text: the copy is chosen where it's shown, so the
/// server's words never reach people.
public enum OutboxProblem: String, CaseIterable, Codable, Sendable, QueryBindable {
    /// The server refused one of the entry's photos.
    case photo
    /// The server refused one of its photos' clips.
    case clip
    /// The server refused the spot or edit itself.
    case refused
    /// This device couldn't send it (its files or the answer couldn't be read).
    case device
    case video
    case videoAlreadyThere
}
