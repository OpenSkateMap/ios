public import SQLiteData

public enum SpotKind: String, CaseIterable, Codable, Sendable, QueryBindable {
    case street
    case park
    case diy
    case plaza
}
