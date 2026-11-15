import Foundation
public import SpotModelKit

public struct SpotEdits: Equatable, Sendable {

    // MARK: Nested Types

    public struct Coordinate: Equatable, Sendable {
        public var latitude: Double
        public var longitude: Double

        public init(latitude: Double, longitude: Double) {
            self.latitude = latitude
            self.longitude = longitude
        }
    }

    // MARK: Static Properties

    public static let none = SpotEdits()

    /// About a centimetre: smaller moves are map jitter, not a moved pin.
    private static let coordinateTolerance = 1e-7

    // MARK: Computed Properties

    public var isEmpty: Bool {
        self == .none
    }

    // MARK: Properties

    public var title: String?
    public var about: String?
    public var kind: SpotKind?
    public var obstacles: [String]?
    public var condition: SpotCondition?
    public var coordinate: Coordinate?
    public var photoIDs: [String]?

    // MARK: Lifecycle

    public init(title: String? = nil,
                about: String? = nil,
                kind: SpotKind? = nil,
                obstacles: [String]? = nil,
                condition: SpotCondition? = nil,
                coordinate: Coordinate? = nil,
                photoIDs: [String]? = nil) {
        self.title = title
        self.about = about
        self.kind = kind
        self.obstacles = obstacles
        self.condition = condition
        self.coordinate = coordinate
        self.photoIDs = photoIDs
    }

    public init(from card: ReviewCard, to draft: ReviewDraft) {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let about = draft.about.trimmingCharacters(in: .whitespacesAndNewlines)
        let obstacles = draft.obstacles.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let moved = abs(draft.latitude - card.latitude) > Self.coordinateTolerance
            || abs(draft.longitude - card.longitude) > Self.coordinateTolerance
        self.init(
            title: title == card.title ? nil : title,
            about: about == card.about ? nil : about,
            kind: draft.kind == card.kind ? nil : draft.kind,
            obstacles: obstacles == card.obstacles ? nil : obstacles,
            condition: draft.condition == card.condition ? nil : draft.condition,
            coordinate: moved ? Coordinate(latitude: draft.latitude, longitude: draft.longitude) : nil,
            photoIDs: draft.photoIDs == card.photos.map(\.id) ? nil : draft.photoIDs,
        )
    }
}
