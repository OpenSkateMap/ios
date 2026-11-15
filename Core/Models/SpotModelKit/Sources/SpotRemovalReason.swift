public import SQLiteData

public enum SpotRemovalReason: String, CaseIterable, Codable, Sendable, QueryBindable {
    case duplicate
    case privateProperty = "private_property"
    case unsafeOrGone = "unsafe_or_gone"
    case notASpot = "not_a_spot"
    case other
}
