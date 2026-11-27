import CoreLocation
import CustomDump
import Foundation
import SpotModelKit
import Testing
@testable import LibraryMatchKit

// MARK: - LibraryMatcherTests

@Suite(.timeLimit(.minutes(1)))
struct LibraryMatcherTests {

    // MARK: Static Properties

    static let undercroft = SpotPoint(id: "undercroft", latitude: 51.5066, longitude: -0.1169, kind: .street)
    static let park = SpotPoint(id: "park", latitude: 51.5200, longitude: -0.1000, kind: .park)
    static let now = Date(timeIntervalSince1970: 1_795_000_000)

    static var london: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }

    // MARK: Static Functions

    /// `meters` north of `spot`.
    static func asset(_ id: String,
                      near spot: SpotPoint = undercroft,
                      meters: Double = 10,
                      takenAt: Date = now.addingTimeInterval(-86400)) -> LibraryAsset {
        LibraryAsset(id: id, latitude: spot.latitude + meters / 111_250, longitude: spot.longitude, takenAt: takenAt)
    }

    static func candidate(_ asset: LibraryAsset, spot: SpotPoint = undercroft) -> LibraryMatcher.Candidate {
        LibraryMatcher.candidates(among: [asset], near: LibraryMatcher.Locator([spot]), calendar: london)[0]
    }

    static func score(_ labels: [String: Float],
                      largestFace: Double = 0,
                      asset: LibraryAsset = asset("a"),
                      spot: SpotPoint = undercroft) -> Double? {
        LibraryMatcher.score(
            ImageAnalysis(labels: labels, largestFace: largestFace),
            for: candidate(asset, spot: spot),
            now: now,
        )
    }

    // MARK: Functions

    @Test
    func `a photo matches a spot within 50 m and no further`() {
        let locator = LibraryMatcher.Locator([Self.undercroft, Self.park])

        let found = LibraryMatcher.candidates(
            among: [Self.asset("near", meters: 45), Self.asset("far", meters: 55)],
            near: locator,
            calendar: Self.london,
        )

        expectNoDifference(found.map(\.asset.id), ["near"])
        expectNoDifference(found.map(\.spot.id), ["undercroft"])
    }

    @Test
    func `a photo between two spots goes to the nearer one`() {
        let ledges = SpotPoint(id: "ledges", latitude: Self.undercroft.latitude + 40 / 111_250, longitude: -0.1169, kind: .street)
        let locator = LibraryMatcher.Locator([ledges, Self.undercroft])

        let found = LibraryMatcher.candidates(among: [Self.asset("a", meters: 30)], near: locator, calendar: Self.london)

        expectNoDifference(found.map(\.spot.id), ["ledges"])
    }

    @Test
    func `one match per spot and day of shooting, the best of them`() {
        let morning = Self.now.addingTimeInterval(-3 * 86400)
        let scored = [
            LibraryMatcher.Scored(candidate: Self.candidate(Self.asset("plain", takenAt: morning)), score: 0.4),
            LibraryMatcher.Scored(
                candidate: Self.candidate(Self.asset("trick", takenAt: morning.addingTimeInterval(600))),
                score: 1.4,
            ),
            LibraryMatcher.Scored(
                candidate: Self.candidate(Self.asset("next day", takenAt: morning.addingTimeInterval(86400))),
                score: 0.5,
            ),
        ]

        let best = LibraryMatcher.best(of: scored)

        expectNoDifference(best.map(\.assetID), ["trick", "next day"])
        expectNoDifference(Set(best.map(\.id)).count, 2)
    }

    @Test
    func `the day is the device calendar's, not UTC's`() throws {
        // 23:30 and 00:30 in London in summer, both on the same UTC day.
        let lateEvening = try #require(ISO8601DateFormatter().date(from: "2026-07-01T22:30:00Z"))
        let afterMidnight = try #require(ISO8601DateFormatter().date(from: "2026-07-01T23:30:00Z"))

        expectNoDifference(LibraryMatcher.day(of: lateEvening, in: Self.london), "2026-07-01")
        expectNoDifference(LibraryMatcher.day(of: afterMidnight, in: Self.london), "2026-07-02")
    }

    @Test
    func `a skater ranks over an empty spot, which ranks over a photo without either`() throws {
        let skater = try #require(Self.score(["skateboarding": 0.9]))
        let stairs = try #require(Self.score(["stairs": 0.9]))
        let unknown = try #require(Self.score([:]))

        #expect(skater > stairs)
        #expect(stairs > unknown)
    }

    @Test
    func `newer and closer break ties`() throws {
        let older = try #require(Self.score([:], asset: Self.asset("old", takenAt: Self.now.addingTimeInterval(-800 * 86400))))
        let newer = try #require(Self.score([:], asset: Self.asset("new", takenAt: Self.now.addingTimeInterval(-10 * 86400))))
        let farther = try #require(Self.score([:], asset: Self.asset("far", meters: 40)))
        let closer = try #require(Self.score([:], asset: Self.asset("close", meters: 5)))

        #expect(newer > older)
        #expect(closer > farther)
    }

    @Test
    func `clear non-matches are dropped unless the spot is in them`() {
        expectNoDifference(Self.score(["food": 0.8]), nil)
        expectNoDifference(Self.score(["interior_room": 0.7]), nil)
        expectNoDifference(Self.score(["people": 0.9, "adult": 0.9], largestFace: 0.2), nil)
        #expect(Self.score(["people": 0.9, "skateboard": 0.6], largestFace: 0.2) != nil)
        #expect(Self.score(["people": 0.9, "stairs": 0.5], largestFace: 0.2) != nil)
    }

    @Test
    func `a skater mid-air, seen only as people, stays`() {
        // Vision's answer for the dark test photo of a skater in the air, the board out of frame.
        #expect(Self.score(["people": 0.91, "adult": 0.91, "structure": 0.02], largestFace: 0.005) != nil)
    }

    @Test
    func `a skatepark counts only at a park`() throws {
        let atPark = try #require(Self.score(["skatepark": 0.9], asset: Self.asset("a", near: Self.park), spot: Self.park))
        let atStreet = try #require(Self.score(["skatepark": 0.9]))

        #expect(atPark > atStreet + 0.5)
    }

    @Test
    func `the digest follows the spots, not their order`() {
        let moved = SpotPoint(id: "park", latitude: 51.53, longitude: -0.1, kind: .park)

        expectNoDifference(
            LibraryMatcher.digest(of: [Self.undercroft, Self.park]),
            LibraryMatcher.digest(of: [Self.park, Self.undercroft]),
        )
        #expect(LibraryMatcher.digest(of: [Self.undercroft, Self.park]) != LibraryMatcher.digest(of: [Self.undercroft, moved]))
    }
}
