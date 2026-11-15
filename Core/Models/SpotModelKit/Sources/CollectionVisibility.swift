public import SQLiteData

public enum CollectionVisibility: String, CaseIterable, Codable, Sendable, QueryBindable {
    case `private`
    case `public`
}
