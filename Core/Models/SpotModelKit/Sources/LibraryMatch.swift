public import Foundation
public import SQLiteData

/// A photo in the person's library taken at a spot: the best one per spot and day of shooting.
@Table("library_match")
public struct LibraryMatch: Identifiable, Equatable, Sendable {
    public let id: String
    /// The asset's PhotoKit local identifier.
    public var assetID: String
    public var spotID: String
    /// The day it was taken in the device's calendar, `yyyy-MM-dd`.
    public var day: String
    public var takenAt: Date
    public var distanceMeters: Double
    /// Higher is likelier a shot of the spot; only compared between matches.
    public var score: Double
    public var state: LibraryMatchState

    public init(assetID: String,
                spotID: String,
                day: String,
                takenAt: Date,
                distanceMeters: Double,
                score: Double,
                state: LibraryMatchState = .new) {
        id = Self.id(spotID: spotID, day: day)
        self.assetID = assetID
        self.spotID = spotID
        self.day = day
        self.takenAt = takenAt
        self.distanceMeters = distanceMeters
        self.score = score
        self.state = state
    }

    public static func id(spotID: String, day: String) -> String {
        "\(spotID)/\(day)"
    }
}
