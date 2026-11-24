import CustomDump
import Foundation
import SQLiteData
import SQLiteKit
import Testing
@testable import SpotModelKit

@Suite(.timeLimit(.minutes(1)))
struct DraftPhotoTests {
    private let database: any DatabaseWriter

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.contributions])
        try database.write { db in
            try SubmissionDraft.insert {
                SubmissionDraft(
                    id: "draft",
                    title: "Undercroft",
                    about: "",
                    kind: .plaza,
                    obstacles: [],
                    condition: .skateable,
                    latitude: 51.5066,
                    longitude: -0.1169,
                    note: "",
                    createdAt: Date(timeIntervalSince1970: 1_000_000),
                )
            }
            .execute(db)
        }
    }

    @Test
    func `a draft photo keeps its clip, and is fully uploaded only once its clip is`() throws {
        let clip = DraftClip(id: "clip", fileName: "clip.mp4", width: 720, height: 1280, durationMs: 4000, bytes: 900_000)
        let photos = [
            photo("with", clip: clip),
            photo("without", clip: nil),
        ]
        try database.write { db in try DraftPhoto.insert { photos }.execute(db) }
        let added = try database.read { db in try DraftPhoto.order(by: \.position).fetchAll(db) }
        expectNoDifference(added, photos)
        expectNoDifference(added.map(\.fileNames), [["with.jpg", "clip.mp4"], ["without.jpg"]])
        expectNoDifference(added.map(\.isFullyUploaded), [false, true])

        var uploaded = clip
        uploaded.isUploaded = true
        try database.write { db in
            try DraftPhoto.find("with").update { $0.clip = #bind(uploaded) }.execute(db)
        }

        let stored = try database.read { db in try DraftPhoto.order(by: \.position).fetchAll(db) }
        expectNoDifference(stored.map(\.clip), [uploaded, nil])
        expectNoDifference(stored.map(\.isFullyUploaded), [true, true])
    }

    private func photo(_ id: String, clip: DraftClip?) -> DraftPhoto {
        DraftPhoto(
            id: id,
            draftID: "draft",
            position: clip == nil ? 1 : 0,
            fileName: "\(id).jpg",
            width: 10,
            height: 10,
            thumbhash: "",
            credit: nil,
            sourceURL: nil,
            isUploaded: true,
            clip: clip,
        )
    }
}
