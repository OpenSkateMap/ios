public import SQLiteData

public enum OutboxStatus: String, CaseIterable, Codable, Sendable, QueryBindable {
    case pending
    case uploading
    case failed
}
