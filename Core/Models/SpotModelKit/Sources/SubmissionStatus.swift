public import SQLiteData

public enum SubmissionStatus: String, CaseIterable, Codable, Sendable, QueryBindable {
    case pending
    case approved
    case rejected
}
