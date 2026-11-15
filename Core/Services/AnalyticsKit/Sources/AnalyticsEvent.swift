// MARK: - AnalyticsEvent

/// Intent only the app sees; outcomes (submissions, votes, reviews) come from the server. Never free text, names or emails.
public enum AnalyticsEvent: Equatable, Sendable {
    case spotOpened(spotID: String, from: SpotSource)
    case placeOpened
    case directionsOpened(spotID: String, app: String)
    case spotShared(spotID: String, activity: String?)
    case filtersChanged(kinds: Int, conditions: Int, obstacles: Int)

    // MARK: Types

    public enum SpotSource: String, Sendable {
        case map
        case list
        case recent
        case nearby
        case search
        case link
    }

    // MARK: Computed Properties

    var name: String {
        switch self {
        case .spotOpened: "spot_opened"
        case .placeOpened: "place_opened"
        case .directionsOpened: "directions_opened"
        case .spotShared: "spot_shared"
        case .filtersChanged: "filters_changed"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .spotOpened(let spotID, let source): ["spot_id": spotID, "source": source.rawValue]
        case .placeOpened: [:]
        case .directionsOpened(let spotID, let app): ["spot_id": spotID, "app": app]
        case .spotShared(let spotID, let activity): ["spot_id": spotID, "activity": activity ?? "unknown"]
        case .filtersChanged(let kinds, let conditions, let obstacles):
            ["kinds": kinds, "conditions": conditions, "obstacles": obstacles]
        }
    }
}
