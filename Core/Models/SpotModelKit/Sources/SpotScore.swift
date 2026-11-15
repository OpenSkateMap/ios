public import SQLiteData

/// `score` is the server's Wilson score: the lower bound of the 95% interval of up / (up + down), 0…1.
@Table("spot_score")
public struct SpotScore: Identifiable, Equatable, Sendable {
    public let id: String
    public var up: Int
    public var down: Int
    public var score: Double

    public init(id: String, up: Int, down: Int, score: Double) {
        self.id = id
        self.up = up
        self.down = down
        self.score = score
    }
}
