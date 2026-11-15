import FactoryKit
import MapKit
import Observation
import os
import SpotModelKit
import SQLiteData
import SQLiteKit

@MainActor
@Observable
final class SpotSearchModel {

    // MARK: Types

    struct Place: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let completion: MKLocalSearchCompletion
    }

    enum Content {
        case browsing(recent: [SpotIndex], nearby: [SpotIndex])
        case results(spots: [SpotIndex], places: [Place])
    }

    // MARK: Static Properties

    private static let typingPause = Duration.milliseconds(120)
    private static let spotLimit = 30
    private nonisolated static let nearbyLimit = 12
    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "search")

    // MARK: Computed Properties

    var content: Content {
        if query.isEmpty {
            .browsing(recent: recent, nearby: nearby)
        } else {
            .results(spots: spots, places: places)
        }
    }

    // MARK: Properties

    private(set) var query = ""
    private(set) var spots = [SpotIndex]()
    private(set) var places = [Place]()
    private(set) var recent = [SpotIndex]()
    private(set) var nearby = [SpotIndex]()
    private(set) var resolvingPlaceID: Place.ID?

    @ObservationIgnored let cityName: (SpotIndex) -> String?

    @ObservationIgnored @Injected(\.database) private var database
    @ObservationIgnored private let recentSpots: RecentSpots
    @ObservationIgnored private let completer = PlaceCompleter()
    @ObservationIgnored private var region: MKCoordinateRegion?
    @ObservationIgnored private var searching: Task<Void, Never>?
    @ObservationIgnored private var browsing: Task<Void, Never>?

    // MARK: Lifecycle

    init(cityName: @escaping (SpotIndex) -> String?, recentSpots: RecentSpots = RecentSpots()) {
        self.cityName = cityName
        self.recentSpots = recentSpots
        completer.onUpdate = { [weak self] completions in
            self?.places = completions.map {
                Place(id: "\($0.title)|\($0.subtitle)", title: $0.title, subtitle: $0.subtitle, completion: $0)
            }
        }
    }

    isolated deinit {
        searching?.cancel()
        browsing?.cancel()
    }

    // MARK: Static Functions

    static func ranked(_ spots: [SpotIndex], query: String, center: CLLocationCoordinate2D?) -> [SpotIndex] {
        let lowered = query.lowercased()
        return spots.sorted { lhs, rhs in
            let lhsPrefix = lhs.title.lowercased().hasPrefix(lowered)
            let rhsPrefix = rhs.title.lowercased().hasPrefix(lowered)
            if lhsPrefix != rhsPrefix {
                return lhsPrefix
            }
            guard let center else {
                return lhs.title < rhs.title
            }
            return distance(lhs, center) < distance(rhs, center)
        }
    }

    static func pattern(_ query: String) -> String {
        let escaped = query
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
        return "%\(escaped)%"
    }

    private static func distance(_ spot: SpotIndex, _ center: CLLocationCoordinate2D) -> Double {
        let latitude = spot.latitude - center.latitude
        let longitude = (spot.longitude - center.longitude) * cos(center.latitude * .pi / 180)
        return latitude * latitude + longitude * longitude
    }

    // MARK: Functions

    func resolve(_ place: Place) async -> (region: MKCoordinateRegion, mark: MKPointAnnotation)? {
        resolvingPlaceID = place.id
        defer {
            if resolvingPlaceID == place.id {
                resolvingPlaceID = nil
            }
        }
        return await PlaceCompleter.place(for: place.completion)
    }

    func open(over region: MKCoordinateRegion) {
        self.region = region
        loadBrowsing()
    }

    func setQuery(_ query: String) {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query != self.query else {
            return
        }
        self.query = query
        completer.complete(query, near: region)
        search()
    }

    func clearRecent() {
        recentSpots.clear()
        recent = []
        loadBrowsing()
    }

    private func search() {
        searching?.cancel()
        guard !query.isEmpty else {
            spots = []
            return
        }
        let query = query
        let center = region?.center
        searching = Task { [weak self] in
            try? await Task.sleep(for: Self.typingPause)
            guard let self, !Task.isCancelled else {
                return
            }
            do {
                let pattern = Self.pattern(query)
                let rows = try await database.read { db in
                    try SpotIndex.where { $0.title.like(pattern, escape: "\\") }.limit(200).fetchAll(db)
                }
                guard !Task.isCancelled else {
                    return
                }
                spots = Array(Self.ranked(rows, query: query, center: center).prefix(Self.spotLimit))
            } catch {
                Self.logger.error("Searching spots failed: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
    }

    private func loadBrowsing() {
        browsing?.cancel()
        let ids = recentSpots.ids
        let region = region
        let box = region.map { SpotsMapModel.box(around: $0) }
        browsing = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                let (recentRows, nearbyRows) = try await database.read { db in
                    let recent = try SpotIndex.where { $0.id.in(ids) }.fetchAll(db)
                    var nearby = [SpotIndex]()
                    if let box, let center = region?.center {
                        nearby = try SpotIndex.nearest(
                            toLatitude: center.latitude,
                            longitude: center.longitude,
                            in: box,
                            limit: Self.nearbyLimit,
                        )
                        .fetchAll(db)
                    }
                    return (recent, nearby)
                }
                guard !Task.isCancelled else {
                    return
                }
                let byID = Dictionary(uniqueKeysWithValues: recentRows.map { ($0.id, $0) })
                recent = ids.compactMap { byID[$0] }
                nearby = nearbyRows
            } catch {
                Self.logger.error("Loading recent spots failed: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
    }
}
