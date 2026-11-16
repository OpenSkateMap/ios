import ComponentKit
import FactoryKit
import Foundation
import ImageKit
import Nuke
import SnapshotTesting
import SpotModelKit
import Testing
import UIKit
@testable import SpotDetailKit

// MARK: - SpotPageViewTests

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)), .tags(.snapshot))
struct SpotPageViewTests {

    // MARK: Static Properties

    private static let width: CGFloat = 402
    private static let photosBase = URL(string: "https://photos.invalid")!

    // MARK: Lifecycle

    init() {
        // As the app sets it at launch.
        UIView.followLayoutDirection()
    }

    // MARK: Helpers

    private static func summary(_ direction: UITraitEnvironmentLayoutDirection = .leftToRight) -> Snapshotting<UIView, UIImage> {
        .image(
            precision: 0.995,
            perceptualPrecision: 0.98,
            size: CGSize(width: width, height: SpotSheetViewController.smallDetentHeight),
            traits: traits(.large, direction),
        )
    }

    private static func page(_ view: SpotPageView,
                             contentSize: UIContentSizeCategory = .large,
                             direction: UITraitEnvironmentLayoutDirection = .leftToRight) -> Snapshotting<UIView, UIImage> {
        // Buttons apply their configurations (fonts included) when laid out; measure after that.
        view.frame.size.width = width
        view.layoutIfNeeded()
        let height = view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return .image(
            precision: 0.995,
            perceptualPrecision: 0.98,
            size: CGSize(width: width, height: height),
            traits: traits(contentSize, direction),
        )
    }

    private static func pageView(contentSize: UIContentSizeCategory = .large,
                                 direction: UITraitEnvironmentLayoutDirection = .leftToRight) -> SpotPageView {
        let view = SpotPageView()
        view.backgroundColor = .systemBackground
        view.summaryHeight = SpotSheetViewController.smallDetentHeight
        view.traitOverrides.displayScale = 1
        view.traitOverrides.preferredContentSizeCategory = contentSize
        view.traitOverrides.userInterfaceStyle = .light
        view.traitOverrides.layoutDirection = direction
        view.updateTraitsIfNeeded()
        return view
    }

    private static func traits(_ contentSize: UIContentSizeCategory,
                               _ direction: UITraitEnvironmentLayoutDirection = .leftToRight) -> UITraitCollection {
        UITraitCollection {
            $0.displayScale = 1
            $0.preferredContentSizeCategory = contentSize
            $0.userInterfaceStyle = .light
            $0.layoutDirection = direction
        }
    }

    // MARK: Functions

    @Test
    func `a spot with photos shows its cover first, in the summary and on the page`() throws {
        try withSeededPhotos {
            let view = Self.pageView()
            view.show(.southbank, address: "Belvedere Road, London SE1 8XX")
            assertSnapshot(of: view, as: Self.summary(), named: "summary")
            assertSnapshot(of: view, as: Self.page(view), named: "page")
        }
    }

    @Test
    func `right to left, the actions run from Directions on the right and the star sits bottom left`() throws {
        try withSeededPhotos {
            let view = Self.pageView(direction: .rightToLeft)
            view.show(.southbank, address: "Belvedere Road, London SE1 8XX")
            assertSnapshot(of: view, as: Self.summary(.rightToLeft), named: "summary")
            assertSnapshot(of: view, as: Self.page(view, direction: .rightToLeft), named: "page")
        }
    }

    @Test
    func `right to left, the cover pages from the right, the next photo waiting on its left`() throws {
        try withSeededPhotos {
            let side: CGFloat = 300
            let canvas = UIView(frame: CGRect(x: 0, y: 0, width: side * 2 + 12, height: side * 0.75))
            canvas.backgroundColor = .systemBackground
            canvas.traitOverrides.displayScale = 1
            canvas.traitOverrides.layoutDirection = .rightToLeft
            let cover = CoverCardView()
            // Unclipped, so the page after the first shows beside the card.
            cover.clipsToBounds = false
            canvas.addSubview(cover)
            cover.frame = CGRect(x: side + 12, y: 0, width: side, height: canvas.bounds.height)
            let page = SpotPage.southbank
            cover.show(try #require(page.spot), photos: page.photos, scale: 1)
            assertSnapshot(
                of: canvas,
                as: .image(
                    precision: 0.995,
                    perceptualPrecision: 0.98,
                    size: canvas.bounds.size,
                    traits: Self.traits(.large, .rightToLeft),
                ),
            )
        }
    }

    @Test
    func `a spot without a photo gets its kind's colour`() throws {
        try withSeededPhotos {
            let view = Self.pageView()
            view.show(.noPhoto, address: "Mile End Park, London E3 4QY")
            assertSnapshot(of: view, as: Self.summary(), named: "summary")
        }
    }

    @Test
    func `large text keeps the title and the actions readable`() throws {
        try withSeededPhotos {
            let view = Self.pageView(contentSize: .accessibilityLarge)
            view.show(.southbank, address: "Belvedere Road, London SE1 8XX")
            assertSnapshot(of: view, as: Self.page(view, contentSize: .accessibilityLarge), named: "page")
        }
    }

    private func withSeededPhotos(_ body: () throws -> Void) throws {
        let pipeline = ImagePipeline(configuration: ImagePipeline.Configuration())
        let urls = PhotoURLBuilder(baseURL: Self.photosBase)
        Container.shared.imagePipeline.register { pipeline }
        Container.shared.photoURLBuilder.register { urls }
        defer {
            Container.shared.imagePipeline.reset()
            Container.shared.photoURLBuilder.reset()
            pipeline.cache.removeAll()
        }
        for (key, file) in [("photos/hall.jpg", "SpotPhoto"), ("photos/tunnel.jpg", "SpotPhoto2")] {
            let url = try #require(urls.url(for: key, size: .card, scale: 1))
            let image = try #require(Bundle(for: BundleToken.self).url(forResource: file, withExtension: "jpg").flatMap {
                UIImage(contentsOfFile: $0.path)
            })
            let request = ImageRequest(url: url, userInfo: [ImagePipelines.useCase: ImagePipelines.UseCase.photo.rawValue])
            pipeline.cache[request] = ImageContainer(image: image)
        }
        try body()
    }
}

// MARK: - BundleToken

private final class BundleToken { }

extension SpotPage {
    fileprivate static let southbank = SpotPage(
        spot: SpotIndex(
            id: "southbank",
            title: "Southbank Undercroft",
            kind: .plaza,
            condition: .skateable,
            cityID: "london",
            latitude: 51.5066,
            longitude: -0.1169,
            version: 1,
            coverKey: "photos/hall.jpg",
            coverWidth: 900,
            coverHeight: 600,
        ),
        detail: SpotDetail(
            id: "southbank",
            about: "The birthplace of British street skating, under the Queen Elizabeth Hall. Smooth floor, banks and the famous ledges.",
            obstacles: ["ledges", "banks", "stairs"],
            addedByID: "rider",
            addedByName: "Local Rider",
            createdAt: Date(timeIntervalSince1970: 1_790_000_000),
            version: 1,
            fetchedAt: Date(timeIntervalSince1970: 1_790_000_000),
            upvotes: 12,
            downvotes: 2,
            myVote: .up,
        ),
        photos: [
            SpotPhoto(
                id: "p1",
                spotID: "southbank",
                key: "photos/hall.jpg",
                width: 900,
                height: 600,
                thumbhash: "",
                credit: "@local.rider",
                position: 0,
            ),
            SpotPhoto(
                id: "p2",
                spotID: "southbank",
                key: "photos/tunnel.jpg",
                width: 900,
                height: 600,
                thumbhash: "",
                credit: nil,
                position: 1,
            ),
        ],
        city: City(
            id: "london",
            slug: "london",
            name: "London",
            countryCode: "GB",
            minLatitude: 51.28,
            minLongitude: -0.51,
            maxLatitude: 51.69,
            maxLongitude: 0.33,
        ),
    )

    fileprivate static let noPhoto = SpotPage(
        spot: SpotIndex(
            id: "mile-end",
            title: "Mile End Skatepark",
            kind: .park,
            condition: .skateable,
            cityID: "london",
            latitude: 51.518,
            longitude: -0.034,
            version: 1,
        ),
        detail: nil,
        photos: [],
        city: southbank.city,
    )
}
