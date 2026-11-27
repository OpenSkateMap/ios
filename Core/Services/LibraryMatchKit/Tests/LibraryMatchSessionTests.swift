import CustomDump
import Foundation
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import LibraryMatchKit

// MARK: - LibraryMatchSessionTests

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LibraryMatchSessionTests {

    // MARK: Properties

    private let photos = FakePhotoLibrary()
    private let database: any DatabaseWriter
    private let engine: LibraryMatchEngine
    private let session: LibraryMatchSession

    // MARK: Lifecycle

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots, .libraryMatches])
        engine = LibraryMatchEngine(
            database: database,
            library: photos.library,
            classifier: photos.classifier,
            now: { LibraryMatcherTests.now },
            calendar: LibraryMatcherTests.london,
        )
        session = LibraryMatchSession(engine: engine, library: photos.library)
    }

    // MARK: Functions

    @Test
    func `before access was asked for, a refresh shows the card and never asks`() async {
        expectNoDifference(session.phase, .unknown)

        await session.refresh()

        expectNoDifference(session.phase, .notAsked)
        expectNoDifference(photos.prompts, 0)
        expectNoDifference(photos.reads, [])
    }

    @Test
    func `Find My Shots asks, scans and ends ready`() async {
        await session.findMyShots()

        expectNoDifference(session.phase, .ready)
        expectNoDifference(photos.prompts, 1)
        expectNoDifference(photos.reads, ["all"])
    }

    @Test
    func `denied access says so and scans nothing`() async {
        photos.answerPrompt(with: .denied)

        await session.findMyShots()

        expectNoDifference(session.phase, .denied)
        expectNoDifference(photos.reads, [])
    }

    @Test
    func `limited access scans what was shared and ends limited`() async {
        photos.answerPrompt(with: .limited)

        await session.findMyShots()

        expectNoDifference(session.phase, .limited)
        expectNoDifference(photos.reads, ["all"])
    }

    @Test
    func `the phase shows the scan while it runs`() async {
        photos.setAccess(.full)
        photos.holdNextRead()
        async let scanned: Void = session.refresh()
        for await _ in photos.readHeld {
            break
        }

        expectNoDifference(session.phase, .scanning(progress: 0))
        photos.releaseReads()
        await scanned

        expectNoDifference(session.phase, .ready)
        expectNoDifference(photos.reads, ["all"])
    }

    @Test
    func `access changing under a scan replaces it`() async {
        photos.setAccess(.limited)
        photos.holdNextRead()
        async let first: Void = session.refresh()
        for await _ in photos.readHeld {
            break
        }

        photos.setAccess(.full)
        await session.refresh()
        await first

        expectNoDifference(session.phase, .ready)
        expectNoDifference(photos.reads, ["all"])
    }

    @Test
    func `a scan the account's end cancels leaves the phase to the next refresh`() async {
        photos.setAccess(.full)
        photos.holdNextRead()
        async let scanned: Void = session.refresh()
        for await _ in photos.readHeld {
            break
        }

        await engine.reset()
        await scanned

        expectNoDifference(session.phase, .unknown)
        await session.refresh()
        expectNoDifference(session.phase, .ready)
    }

    @Test
    func `access taken away stops showing the scan`() async {
        photos.setAccess(.full)
        await session.refresh()

        photos.setAccess(.denied)
        await session.refresh()

        expectNoDifference(session.phase, .denied)
    }
}
