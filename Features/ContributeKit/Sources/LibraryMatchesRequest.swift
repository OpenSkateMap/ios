import Foundation
import SpotModelKit
import SQLiteData

// MARK: - LibraryMatchesRequest

/// The waiting library matches whose spot is still public and standing, likeliest first.
nonisolated struct LibraryMatchesRequest: FetchKeyRequest, Hashable {
    static let limit = 20

    func fetch(_ db: Database) throws -> [LibraryMatchCard] {
        let matches = try LibraryMatch
            .where { $0.state.eq(LibraryMatchState.new) }
            .order { ($0.score.desc(), $0.takenAt.desc()) }
            .limit(Self.limit * 3)
            .fetchAll(db)
        let spotIDs = Array(Set(matches.map(\.spotID)))
        let titles = try Dictionary(
            SpotIndex
                .where { $0.id.in(spotIDs) && !$0.isPrivate && $0.condition.neq(SpotCondition.demolished) }
                .select { ($0.id, $0.title) }
                .fetchAll(db),
            uniquingKeysWith: { first, _ in first },
        )
        return Array(
            matches
                .compactMap { match in titles[match.spotID].map { LibraryMatchCard(match: match, spotTitle: $0) } }
                .prefix(Self.limit)
        )
    }
}

// MARK: - LibraryMatchCard

nonisolated struct LibraryMatchCard: Identifiable, Equatable, Sendable {
    var id: LibraryMatch.ID {
        match.id
    }

    let match: LibraryMatch
    let spotTitle: String
}
