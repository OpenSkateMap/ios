import CoreLocation
import Foundation
import SpotModelKit

// MARK: - LibraryMatcher

/// Which photos were taken at a spot, how likely each is a shot of it, and the best one per spot and day.
nonisolated enum LibraryMatcher {

    // MARK: Nested Types

    struct Candidate: Equatable, Sendable {
        let asset: LibraryAsset
        let spot: SpotPoint
        let distanceMeters: Double
        let day: String
    }

    struct Scored: Equatable, Sendable {
        let candidate: Candidate
        let score: Double
    }

    /// Spots sorted by latitude: a photo is measured only against the thin band of them within reach.
    struct Locator {
        private let spots: [SpotPoint]

        init(_ spots: [SpotPoint]) {
            self.spots = spots.sorted { $0.latitude < $1.latitude }
        }

        func nearest(to asset: LibraryAsset) -> (spot: SpotPoint, meters: Double)? {
            let band = LibraryMatcher.radiusMeters / LibraryMatcher.metersPerDegreeLatitude
            var index = firstIndex(atOrAbove: asset.latitude - band)
            let here = CLLocation(latitude: asset.latitude, longitude: asset.longitude)
            var nearest: (spot: SpotPoint, meters: Double)?
            while index < spots.count, spots[index].latitude <= asset.latitude + band {
                let spot = spots[index]
                let meters = here.distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude))
                if meters <= LibraryMatcher.radiusMeters, meters < nearest?.meters ?? .infinity {
                    nearest = (spot, meters)
                }
                index += 1
            }
            return nearest
        }

        private func firstIndex(atOrAbove latitude: Double) -> Int {
            var low = 0
            var high = spots.count
            while low < high {
                let middle = (low + high) / 2
                if spots[middle].latitude < latitude {
                    low = middle + 1
                } else {
                    high = middle
                }
            }
            return low
        }
    }

    // MARK: Static Properties

    static let radiusMeters = 50.0

    /// Below the shortest a degree of latitude gets (110.57 km at the equator), so the band never falls short.
    private static let metersPerDegreeLatitude = 110_000.0

    private static let skateLabels: [String: Double] = ["skateboarding": 1, "skateboard": 0.8]
    /// A skatepark is the spot itself only where the spot is a park.
    private static let parkLabel = "skatepark"
    /// What an empty street spot looks like.
    private static let streetLabels: Set = [
        "stairs", "street", "sidewalk", "structure", "bench", "graffiti", "parking_lot", "road", "building", "bridge",
        "cityscape",
    ]
    /// Clear signs a photo isn't of the spot: food, rooms, documents, people on their own.
    private static let nonMatchLabels: Set = [
        "food", "dessert", "drink", "cake", "plate", "interior_room", "kitchen", "bedroom", "living_room", "bathroom",
        "dining_room", "restaurant", "nightclub", "classroom", "document", "receipt", "screenshot", "people", "adult",
        "child", "baby",
    ]

    // MARK: Static Functions

    static func candidates(among assets: [LibraryAsset], near locator: Locator, calendar: Calendar) -> [Candidate] {
        assets.compactMap { asset in
            locator.nearest(to: asset).map { found in
                Candidate(asset: asset, spot: found.spot, distanceMeters: found.meters, day: day(of: asset.takenAt, in: calendar))
            }
        }
    }

    /// Nil for a clear non-match. A skater in frame ranks first, an empty spot's architecture next; newer and closer break
    /// ties. The weights are first guesses, to tune against real libraries.
    static func score(_ labels: [String: Float], for candidate: Candidate, now: Date) -> Double? {
        func confidence(_ label: String) -> Double {
            Double(labels[label] ?? 0)
        }
        var skate = skateLabels.map { confidence($0.key) * $0.value }.max() ?? 0
        if candidate.spot.kind == .park {
            skate = max(skate, confidence(parkLabel) * 0.8)
        }
        let street = streetLabels.map(confidence).max() ?? 0
        let nonMatch = nonMatchLabels.map(confidence).max() ?? 0
        if nonMatch >= 0.5, skate < 0.15, street < 0.3 {
            return nil
        }
        let ageDays = max(0, now.timeIntervalSince(candidate.asset.takenAt) / 86400)
        let recency = 1 / (1 + ageDays / 365)
        let closeness = 1 - candidate.distanceMeters / radiusMeters
        return skate + street * 0.5 + recency * 0.3 + closeness * 0.1
    }

    /// One per spot and day of shooting: the best score, then the newer, then the closer.
    static func best(of scored: [Scored]) -> [LibraryMatch] {
        let grouped = Dictionary(grouping: scored) { LibraryMatch.id(spotID: $0.candidate.spot.id, day: $0.candidate.day) }
        return grouped.values
            .compactMap { group in group.min(by: isBetter) }
            .sorted(by: isBetter)
            .map { best in
                LibraryMatch(
                    assetID: best.candidate.asset.id,
                    spotID: best.candidate.spot.id,
                    day: best.candidate.day,
                    takenAt: best.candidate.asset.takenAt,
                    distanceMeters: best.candidate.distanceMeters,
                    score: best.score,
                )
            }
    }

    static func day(of date: Date, in calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Stable across launches (FNV-1a over the sorted ids and places), unlike `Hasher`: a new or moved spot changes it.
    static func digest(of spots: [SpotPoint]) -> String {
        let text = spots
            .map { "\($0.id)," + String(format: "%.5f,%.5f", $0.latitude, $0.longitude) }
            .sorted()
            .joined(separator: "\n")
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return String(hash, radix: 16)
    }

    private static func isBetter(_ lhs: Scored, _ rhs: Scored) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score > rhs.score
        }
        if lhs.candidate.asset.takenAt != rhs.candidate.asset.takenAt {
            return lhs.candidate.asset.takenAt > rhs.candidate.asset.takenAt
        }
        if lhs.candidate.distanceMeters != rhs.candidate.distanceMeters {
            return lhs.candidate.distanceMeters < rhs.candidate.distanceMeters
        }
        return lhs.candidate.asset.id < rhs.candidate.asset.id
    }
}

// MARK: - SpotPoint

/// A public spot to match photos against.
struct SpotPoint: Equatable, Sendable {
    var id: String
    var latitude: Double
    var longitude: Double
    var kind: SpotKind
}
