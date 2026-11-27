import CustomDump
import Foundation
import LibraryMatchKit
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import ContributeKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct FromYourPhotosTests {

    // MARK: Static Properties

    private static let takenAt = Date(timeIntervalSince1970: 1_773_576_000)
    private static let card = LibraryMatchCard(match: match("undercroft", day: "2026-03-15", score: 1), spotTitle: "Undercroft")

    // MARK: Static Functions

    private static func spot(_ id: String, condition: SpotCondition = .skateable, isPrivate: Bool = false) -> SpotIndex {
        SpotIndex(
            id: id,
            title: id.capitalized,
            kind: .street,
            condition: condition,
            cityID: nil,
            latitude: 51.5,
            longitude: -0.1,
            version: 1,
            isPrivate: isPrivate,
        )
    }

    private static func match(_ spotID: String,
                              day: String,
                              score: Double,
                              state: LibraryMatchState = .new) -> LibraryMatch {
        LibraryMatch(
            assetID: "\(spotID)-\(day)",
            spotID: spotID,
            day: day,
            takenAt: takenAt,
            distanceMeters: 10,
            score: score,
            state: state,
        )
    }

    // MARK: Functions

    @Test
    func `the cards are the waiting matches of standing public spots, likeliest first`() throws {
        let database = try AppDatabase.inMemory(schemas: [.spots, .libraryMatches])
        try database.write { db in
            try SpotIndex.insert {
                [
                    Self.spot("undercroft"),
                    Self.spot("gone", condition: .demolished),
                    Self.spot("secret", isPrivate: true),
                    Self.spot("ledges"),
                ]
            }
            .execute(db)
            try LibraryMatch.insert {
                [
                    Self.match("undercroft", day: "2026-03-01", score: 1),
                    Self.match("undercroft", day: "2026-03-02", score: 2),
                    Self.match("gone", day: "2026-03-01", score: 3),
                    Self.match("secret", day: "2026-03-01", score: 3),
                    Self.match("ledges", day: "2026-03-01", score: 5, state: .skipped),
                    Self.match("ledges", day: "2026-03-02", score: 5, state: .used),
                    Self.match("unindexed", day: "2026-03-01", score: 9),
                ]
            }
            .execute(db)
        }

        let cards = try database.read { db in try LibraryMatchesRequest().fetch(db) }

        expectNoDifference(cards.map(\.id), ["undercroft/2026-03-02", "undercroft/2026-03-01"])
        expectNoDifference(cards.map(\.spotTitle), ["Undercroft", "Undercroft"])
    }

    @Test
    func `the section follows the scan's phase`() {
        let cards = [Self.card]
        let content = FromYourPhotosModel.content(for:matches:)

        expectNoDifference(content(.unknown, []), .hidden)
        expectNoDifference(content(.unknown, cards), .matches(cards, note: nil))
        expectNoDifference(content(.notAsked, []), .prompt(.intro))
        expectNoDifference(content(.denied, cards), .prompt(.denied))
        expectNoDifference(content(.scanning(progress: 0.5), []), .prompt(.scanning(progress: 0.5)))
        expectNoDifference(content(.scanning(progress: 0.5), cards), .matches(cards, note: nil))
        expectNoDifference(content(.ready, []), .prompt(.nothingFound))
        expectNoDifference(content(.ready, cards), .matches(cards, note: nil))
        expectNoDifference(content(.limited, []), .prompt(.limited(nothingFound: true)))
        expectNoDifference(content(.limited, cards), .matches(cards, note: .limited(nothingFound: false)))
    }

    @Test
    func `a card asks about the month this year and the year before`() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "Europe/London"))
        let thisYear = Self.takenAt.addingTimeInterval(30 * 86400)
        let nextYear = Self.takenAt.addingTimeInterval(400 * 86400)

        expectNoDifference(
            LibraryMatchCell.question(for: Self.card, now: thisYear, calendar: calendar),
            "Shot this at Undercroft in March?",
        )
        expectNoDifference(
            LibraryMatchCell.question(for: Self.card, now: nextYear, calendar: calendar),
            "Shot this at Undercroft in 2026?",
        )
    }
}
