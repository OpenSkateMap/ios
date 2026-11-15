public import SQLiteData

public enum SpotVote: Int, CaseIterable, Codable, Sendable, QueryBindable {
    case down = -1
    case none = 0
    case up = 1
}
