import ContributionsKit
import CustomDump
import FactoryKit
import Foundation
import LibraryMatchKit
import Observation
import PhotoUploadKit
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
import UIKit
@testable import ContributeKit

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct LibraryPhotoIntakeTests {

    // MARK: Static Properties

    private static let spot = SpotEditTarget(
        spotID: "undercroft",
        title: "Undercroft",
        about: "",
        kind: .street,
        obstacles: [],
        condition: .skateable,
        latitude: 51.5066,
        longitude: -0.1169,
        address: nil,
        photos: [],
    )

    // MARK: Functions

    @Test
    func `an edit opened with a library photo starts with it, and its match is used once the edit is in the outbox`()
        async throws {
        let database = try AppDatabase.inMemory(schemas: [.spots, .contributions, .libraryMatches])
        let match = LibraryMatch(
            assetID: "asset-1",
            spotID: "undercroft",
            day: "2026-03-15",
            takenAt: Date(timeIntervalSince1970: 1_773_576_000),
            distanceMeters: 12,
            score: 1.2,
        )
        try await database.write { db in try LibraryMatch.insert { match }.execute(db) }
        let jpeg = UIGraphicsImageRenderer(size: CGSize(width: 40, height: 30)).jpegData(withCompressionQuality: 0.8) { context in
            UIColor.orange.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        var library = PhotoLibrary.preview
        library.imageData = { $0 == "asset-1" ? jpeg : nil }
        let files = OutboxFiles(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
        let outbox = ContributionsOutbox(api: .preview, photos: .preview, database: database, files: files)
        let engine = LibraryMatchEngine(database: database, library: library, classifier: .preview)
        let container = Container.shared
        container.manager.push()
        defer { container.manager.pop() }
        container.contributionsSession.register { ContributionsSession(outbox: outbox, photos: .preview) }
        container.photoLibrary.register { library }
        container.libraryMatchSession.register { LibraryMatchSession(engine: engine, library: library) }

        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let model = NewSpotModel(editing: Self.spot, libraryPhotoIDs: ["asset-1"])

            let ids = model.beginLibraryPhotos()
            expectNoDifference(ids.count, 1)
            expectNoDifference(model.beginLibraryPhotos(), [])
            for await isReady in Observations({ model.form.photos.first?.added?.prepared != nil }) where isReady {
                break
            }
            let submission = await model.submit()

            guard case .saved = submission else {
                Issue.record("The edit wasn't saved: \(submission)")
                return
            }
            let state = try await database.read { db in try LibraryMatch.find(match.id).fetchOne(db)?.state }
            expectNoDifference(state, .used)
        }
    }
}
