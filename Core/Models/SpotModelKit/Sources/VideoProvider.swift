public import SQLiteData

public enum VideoProvider: String, CaseIterable, Codable, Sendable, QueryBindable {
    case youtube
    case instagram
}
