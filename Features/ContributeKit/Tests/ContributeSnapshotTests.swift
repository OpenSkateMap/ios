import AccountKit
import ComponentKit
import ContributionsKit
import CustomDump
import FactoryKit
import Foundation
import ImageKit
import PhotoUploadKit
import ReviewKit
import SnapshotTesting
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
import UIKit
@testable import ContributeKit

// MARK: - ContributeSnapshotTests

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct ContributeSnapshotTests {

    // MARK: Static Properties

    /// Noon UTC: the rows' dates read the same from UTC−12 to UTC+11, wherever the tests run.
    private static let now = Date(timeIntervalSince1970: 1_791_633_600)
    private static let london = City(
        id: "london",
        slug: "london",
        name: "London",
        countryCode: "GB",
        minLatitude: 51.28,
        minLongitude: -0.51,
        maxLatitude: 51.69,
        maxLongitude: 0.33,
    )
    private static let thumbhash = "1QcSHQRnh493V4dIh4eXh1h4kJUI"

    // MARK: Lifecycle

    init() {
        // As the app sets it at launch.
        UIView.followLayoutDirection()
    }

    // MARK: Static Functions

    private static func image(style: UIUserInterfaceStyle = .light,
                              contentSize: UIContentSizeCategory = .large,
                              direction: UITraitEnvironmentLayoutDirection = .leftToRight,
                              height: CGFloat? = nil) -> Snapshotting<UIViewController, UIImage> {
        var device = ViewImageConfig.iPhone13Pro
        if let height {
            device.size?.height = height
        }
        return .image(
            on: device,
            precision: 0.995,
            perceptualPrecision: 0.98,
            traits: UITraitCollection {
                $0.displayScale = 1
                $0.userInterfaceStyle = style
                $0.preferredContentSizeCategory = contentSize
                $0.layoutDirection = direction
            },
        )
    }

    private static func navigation(_ root: UIViewController) -> UINavigationController {
        let navigation = UINavigationController(rootViewController: root)
        navigation.navigationBar.prefersLargeTitles = true
        return navigation
    }

    private static func submission(_ id: String,
                                   _ title: String,
                                   _ kind: SpotKind,
                                   _ status: SubmissionStatus,
                                   rejectReason: String? = nil,
                                   daysAgo: Double) -> MySubmission {
        let date = now.addingTimeInterval(-daysAgo * 86400)
        return MySubmission(
            id: id,
            title: title,
            kind: kind,
            cityID: london.id,
            latitude: 51.506,
            longitude: -0.116,
            status: status,
            rejectReason: rejectReason,
            spotID: status == .approved ? "spot-\(id)" : nil,
            coverThumbhash: thumbhash,
            createdAt: date,
            updatedAt: date,
        )
    }

    private static func card() -> ReviewCard {
        ReviewCard(
            id: "card",
            title: "Vauxhall DIY Bowl",
            about: "A concrete bowl and a quarter pipe under the railway.",
            kind: .diy,
            obstacles: ["bowl", "quarter pipe"],
            condition: .skateable,
            latitude: 51.486,
            longitude: -0.124,
            cityID: london.id,
            note: "Added the bowl and the QP",
            photos: [
                ReviewCard.Photo(
                    id: "photo",
                    key: "photos/test.jpg",
                    width: 1024,
                    height: 768,
                    thumbhash: thumbhash,
                    credit: .submitter,
                    isExisting: false,
                )
            ],
            submitterName: "Bristol Barry",
            nearby: [],
            createdAt: now,
            updatedAt: now,
        )
    }

    private static func editCard() -> ReviewCard {
        var card = card()
        card.title = "Well Ledges"
        card.about = "Marble ledges by the river. Quiet before 10am."
        card.kind = .plaza
        card.obstacles = ["ledges", "stairs"]
        card.condition = .knobbed
        card.note = "Knobbed since spring"
        card.spotID = "spot-c"
        card.changedFields = [.condition, .photos]
        card.photos.append(ReviewCard.Photo(
            id: "spot-photo",
            key: "photos/spot.jpg",
            width: 1024,
            height: 768,
            thumbhash: thumbhash,
            credit: .submitter,
            isExisting: true,
        ))
        card.current = ReviewCard.Snapshot(
            title: "Well Ledges",
            about: "Marble ledges by the river. Quiet before 10am.",
            kind: .plaza,
            obstacles: ["ledges", "stairs"],
            condition: .skateable,
            latitude: 51.486,
            longitude: -0.124,
            photoCount: 2,
            removedPhotoCount: 1,
        )
        return card
    }

    // MARK: Functions

    @Test(.tags(.snapshot))
    func `contribute, empty`() throws {
        try withEnvironment(role: .user, submissions: []) {
            assertSnapshot(of: Self.navigation(ContributeViewController()), as: Self.image())
        }
    }

    @Test(.tags(.snapshot))
    func `contribute, empty, accessibility text`() throws {
        try withEnvironment(role: .user, submissions: []) {
            assertSnapshot(
                of: Self.navigation(ContributeViewController()),
                as: Self.image(contentSize: .accessibilityExtraLarge),
            )
        }
    }

    @Test(.tags(.snapshot))
    func `contribute, a curator's spots and queue`() async throws {
        let review = ReviewSession(api: .queue([Self.card()]))
        await review.load()
        let submissions = [
            Self.submission("a", "Queens Walk Ledges", .street, .pending, daysAgo: 0),
            Self.submission("b", "Her Mindset Banks", .street, .rejected, rejectReason: "duplicate", daysAgo: 1),
            Self.submission("c", "Well Ledges", .plaza, .approved, daysAgo: 1),
        ]
        try withEnvironment(role: .admin, submissions: submissions, review: review) {
            assertSnapshot(of: Self.navigation(ContributeViewController()), as: Self.image())
        }
    }

    @Test(.tags(.snapshot))
    func `contribute, a suggested edit in the history`() throws {
        var edit = Self.submission("e", "Well Ledges", .plaza, .pending, daysAgo: 0)
        edit.spotID = "spot-c"
        edit.changedFields = [.condition]
        try withEnvironment(role: .user, submissions: [
            edit,
            Self.submission("c", "Well Ledges", .plaza, .approved, daysAgo: 2),
        ]) {
            assertSnapshot(of: Self.navigation(ContributeViewController()), as: Self.image())
        }
    }

    @Test(.tags(.snapshot))
    func `contribute right to left, your spots lead with their photos on the right`() throws {
        let submissions = [
            Self.submission("a", "Queens Walk Ledges", .street, .pending, daysAgo: 0),
            Self.submission("b", "Her Mindset Banks", .street, .rejected, rejectReason: "duplicate", daysAgo: 1),
            Self.submission("c", "Well Ledges", .plaza, .approved, daysAgo: 1),
        ]
        try withEnvironment(role: .user, submissions: submissions) {
            assertSnapshot(of: Self.navigation(ContributeViewController()), as: Self.image(direction: .rightToLeft))
        }
    }

    @Test
    func `published and private spots open, and a private one says where it went`() throws {
        var secret = Self.submission("p", "Back Garden Rail", .diy, .approved, daysAgo: 0)
        secret.collectionID = "night"
        let night = SpotCollection(
            id: "night",
            name: "Night Sessions",
            about: "",
            visibility: .private,
            kind: .custom,
            look: CollectionLook(color: .sky),
            role: .owner,
            ownerID: "rider",
            ownerName: "Local Rider",
            ownerUsername: "local_rider",
            memberCount: 0,
            coverKey: nil,
            coverThumbhash: nil,
            position: 0,
            createdAt: Self.now,
            updatedAt: Self.now,
        )
        try withEnvironment(role: .user, submissions: [
            secret,
            Self.submission("c", "Well Ledges", .plaza, .approved, daysAgo: 1),
            Self.submission("a", "Queens Walk Ledges", .street, .pending, daysAgo: 2),
        ], collections: [night]) {
            let spots = ContributeModel().spots

            expectNoDifference(spots.map(\.spotID), ["spot-p", "spot-c", nil])
            expectNoDifference(spots.first?.badge, .private(collection: "Night Sessions"))
        }
    }

    @Test(.tags(.snapshot))
    func `review queue, a suggested edit`() async throws {
        let review = ReviewSession(api: .queue([Self.editCard()]))
        await review.load()
        try withEnvironment(role: .admin, submissions: [], review: review) {
            assertSnapshot(of: Self.navigation(ReviewQueueViewController()), as: Self.image())
        }
    }

    @Test(.tags(.snapshot))
    func `new spot, empty`() throws {
        try withEnvironment(role: .user, submissions: []) {
            assertSnapshot(of: NewSpotViewController(model: NewSpotModel()), as: Self.image())
        }
    }

    @Test(.tags(.snapshot))
    func `new spot right to left, its glyphs lead on the right`() throws {
        try withEnvironment(role: .user, submissions: []) {
            assertSnapshot(of: NewSpotViewController(model: NewSpotModel()), as: Self.image(direction: .rightToLeft))
        }
    }

    @Test(.tags(.snapshot))
    func `new spot, accessibility text`() throws {
        try withEnvironment(role: .user, submissions: []) {
            assertSnapshot(
                of: NewSpotViewController(model: NewSpotModel()),
                as: Self.image(contentSize: .accessibilityExtraLarge, height: 2000),
            )
        }
    }

    /// Glass draws only on dark backgrounds in a layer render, so the badges are checked in dark.
    @Test(.tags(.snapshot))
    func `new spot, clips show their length in the corner under the credit`() throws {
        try withEnvironment(role: .user, submissions: []) {
            let model = NewSpotModel()
            let photo = PreparedPhoto(jpeg: Data(), width: 1080, height: 1920, thumbhash: Self.thumbhash)
            for (index, milliseconds) in [12400, 2000, 7000].enumerated() {
                let clip = index == 1
                    ? nil
                    : PreparedClip(
                        file: URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4"),
                        width: 720,
                        height: 1280,
                        durationMs: milliseconds,
                        bytes: 0,
                    )
                model.edit { $0.append(NewSpotForm.Photo(NewSpotForm.Photo.Added(state: .ready(photo), clip: clip))) }
            }
            assertSnapshot(of: NewSpotViewController(model: model), as: Self.image(style: .dark))
        }
    }

    @Test(.tags(.snapshot))
    func `obstacles sheet with selected chips`() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let sheet = OptionSheetViewController(
                title: "Obstacles",
                message: "What's there to skate",
                content: ObstaclesEditorView(selection: ["ledges", "banks"]),
                tint: nil,
                onConfirm: { },
            )
            assertSnapshot(of: sheet, as: Self.image(style: style), named: style == .dark ? "dark" : "light")
        }
    }

    @Test(.tags(.snapshot))
    func `review queue with its controls`() async throws {
        let review = ReviewSession(api: .queue([Self.card()]))
        await review.load()
        try withEnvironment(role: .admin, submissions: [], review: review) {
            for style in [UIUserInterfaceStyle.light, .dark] {
                assertSnapshot(
                    of: Self.navigation(ReviewQueueViewController()),
                    as: Self.image(style: style),
                    named: style == .dark ? "dark" : "light",
                )
            }
        }
    }

    @Test(.tags(.snapshot))
    func `review queue right to left, the card mirrors and the swipe's controls stay put`() async throws {
        let review = ReviewSession(api: .queue([Self.card()]))
        await review.load()
        try withEnvironment(role: .admin, submissions: [], review: review) {
            assertSnapshot(
                of: Self.navigation(ReviewQueueViewController()),
                as: Self.image(style: .dark, direction: .rightToLeft),
            )
        }
    }

    @Test(.tags(.snapshot))
    func `review queue, accessibility text`() async throws {
        let review = ReviewSession(api: .queue([Self.card()]))
        await review.load()
        try withEnvironment(role: .admin, submissions: [], review: review) {
            assertSnapshot(
                of: Self.navigation(ReviewQueueViewController()),
                as: Self.image(style: .dark, contentSize: .accessibilityExtraLarge),
            )
        }
    }

    private func withEnvironment(role: Account.Role,
                                 submissions: [MySubmission],
                                 review: ReviewSession? = nil,
                                 collections: [SpotCollection] = [],
                                 _ body: () throws -> Void) throws {
        let database = try AppDatabase.inMemory(schemas: [.spots, .contributions])
        try database.write { db in
            try City.insert { Self.london }.execute(db)
            if !submissions.isEmpty {
                try MySubmission.insert { submissions }.execute(db)
            }
            if !collections.isEmpty {
                try SpotCollection.insert { collections }.execute(db)
            }
        }
        let account = Account(id: "rider", name: "Local Rider", email: "rider@example.com", role: role, createdAt: Self.now)
        let files = OutboxFiles(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
        let outbox = ContributionsOutbox(api: .preview, photos: .preview, database: database, files: files)

        let container = Container.shared
        container.manager.push()
        defer { container.manager.pop() }
        container.database.register { database }
        // A fresh renderer: the shared one caches by hash, which would make these pixels depend on test order.
        container.thumbHashRenderer.register { ThumbHashRenderer() }
        container.authSession.register {
            AuthSession(apple: .preview, api: .preview, keychain: .preview(signedInAs: account), endAccountScope: { })
        }
        container.contributionsSession.register { ContributionsSession(outbox: outbox, photos: .preview) }
        container.reviewSession.register { review ?? ReviewSession(api: .queue([])) }
        try withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try body()
        }
    }
}

extension ReviewAPIManager {
    fileprivate static func queue(_ cards: [ReviewCard]) -> ReviewAPIManager {
        ReviewAPIManager(
            queue: { _, _ in ReviewQueue(cityIDs: nil, cards: cards) },
            approve: preview.approve,
            reject: preview.reject,
            undo: preview.undo,
            approveVideo: preview.approveVideo,
            rejectVideo: preview.rejectVideo,
            undoVideo: preview.undoVideo,
        )
    }
}
