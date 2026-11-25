import Foundation
public import SQLiteData

/// Spots by name from the local index, best first: every typed word starting a word of the title or a Latin spelling,
/// then the typed text anywhere in one, then, while that finds fewer than asked, words a letter or two off.
public enum SpotSearch {

    // MARK: Types

    private enum Tier: Int, Comparable {
        case words
        case anywhere
        case typo

        static func <(lhs: Tier, rhs: Tier) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    // MARK: Static Properties

    /// Shorter words are matched only exactly: one wrong letter in three finds almost anything.
    private static let shortestFuzzyWord = 4
    /// From this length two wrong letters are allowed, one below it.
    private static let twoTyposFrom = 8
    private static let candidateLimit = 200

    // MARK: Static Functions

    public static func spots(matching query: String,
                             near center: (latitude: Double, longitude: Double)?,
                             limit: Int,
                             _ db: Database) throws -> [SpotIndex] {
        let words = SpotSearchText.words(of: query)
        guard !words.isEmpty else {
            return []
        }
        var tiers = [String: Tier]()
        let pattern = SpotSearchText.pattern(for: words)
        for id in try SpotSearchText.where({ $0.match(pattern) }).order(by: \.rank).select(\.spotID).limit(candidateLimit)
            .fetchAll(db) {
            tiers[id] = .words
        }
        let anywhere = "%\(escapedForLike(words.joined(separator: " ")))%"
        for id in try SpotSearchText
            .where({ $0.title.like(anywhere, escape: "\\") || $0.latin.like(anywhere, escape: "\\") })
            .select(\.spotID)
            .limit(candidateLimit)
            .fetchAll(db) where tiers[id] == nil {
            tiers[id] = .anywhere
        }
        if tiers.count < limit, words.contains(where: { $0.count >= shortestFuzzyWord }) {
            for row in try SpotSearchText.select({ ($0.spotID, $0.title, $0.latin) }).fetchAll(db)
                where tiers[row.0] == nil && isNear(words, to: "\(row.1) \(row.2)") {
                tiers[row.0] = .typo
            }
        }
        let folded = words.joined(separator: " ")
        let spots = try SpotIndex.where { $0.id.in(Array(tiers.keys)) }.fetchAll(db)
        let ranked = spots.map { spot in
            (
                spot: spot,
                tier: tiers[spot.id] ?? .typo,
                leads: SpotSearchText.fold(spot.title).hasPrefix(folded),
                distance: center.map { distance(from: spot, to: $0) } ?? 0,
            )
        }
        .sorted { lhs, rhs in
            if lhs.tier != rhs.tier {
                return lhs.tier < rhs.tier
            }
            if lhs.leads != rhs.leads {
                return lhs.leads
            }
            if lhs.distance != rhs.distance {
                return lhs.distance < rhs.distance
            }
            return lhs.spot.title < rhs.spot.title
        }
        return ranked.prefix(limit).map(\.spot)
    }

    /// Whether every typed word is, or starts, a word of the text with at most the typos its length allows.
    static func isNear(_ words: [String], to text: String) -> Bool {
        let candidates = text.split(separator: " ").map(String.init)
        return words.allSatisfy { word in
            candidates.contains { candidate in
                if candidate.hasPrefix(word) {
                    return true
                }
                guard word.count >= shortestFuzzyWord else {
                    return false
                }
                let allowed = word.count >= twoTyposFrom ? 2 : 1
                return editDistance(word, candidate) <= allowed
                    || editDistance(word, String(candidate.prefix(word.count))) <= allowed
            }
        }
    }

    /// Optimal string alignment distance: insertions, deletions, substitutions and swaps of neighbours.
    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        guard !a.isEmpty else {
            return b.count
        }
        guard !b.isEmpty else {
            return a.count
        }
        var distances = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count {
            distances[i][0] = i
        }
        for j in 0...b.count {
            distances[0][j] = j
        }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                distances[i][j] = min(distances[i - 1][j] + 1, distances[i][j - 1] + 1, distances[i - 1][j - 1] + cost)
                if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
                    distances[i][j] = min(distances[i][j], distances[i - 2][j - 2] + 1)
                }
            }
        }
        return distances[a.count][b.count]
    }

    private static func escapedForLike(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    /// Squared degrees with longitude scaled by latitude: only ever compared, never shown.
    private static func distance(from spot: SpotIndex, to center: (latitude: Double, longitude: Double)) -> Double {
        let latitude = spot.latitude - center.latitude
        let longitude = (spot.longitude - center.longitude) * cos(center.latitude * .pi / 180)
        return latitude * latitude + longitude * longitude
    }
}
