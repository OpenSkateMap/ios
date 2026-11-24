import ComponentKit
import Foundation
import ImageKit
import SnapshotTesting
import SpotModelKit
import Testing
import UIKit
@testable import SpotDetailKit

// MARK: - SpotVideosSectionViewTests

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)), .tags(.snapshot))
struct SpotVideosSectionViewTests {

    // MARK: Static Properties

    private static let thumbnailLoader = ImageLoader(
        image: { _, size in
            UIGraphicsImageRenderer(size: size).image { context in
                UIColor.systemTeal.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
        },
        photo: ImageLoader.placeholder.photo,
    )

    private static var image: Snapshotting<UIView, UIImage> {
        .image(precision: 0.995, perceptualPrecision: 0.98, traits: UITraitCollection { $0.displayScale = 1 })
    }

    // MARK: Lifecycle

    init() {
        // As the app sets it at launch.
        UIView.followLayoutDirection()
    }

    // MARK: Functions

    @Test
    func `videos show as footage cards, the next one peeking in`() {
        assertSnapshot(of: host([.youtube, .instagram], draft: nil), as: Self.image)
    }

    @Test
    func `with no videos yet, it says so in one line`() {
        assertSnapshot(of: host([], draft: nil), as: Self.image)
    }

    @Test
    func `a video the server turned down says why`() {
        let draft = VideoDraft(
            id: "d1",
            spotID: "spot",
            url: "https://youtu.be/dQw4w9WgXcQ",
            caption: "",
            status: .failed,
            problem: .videoAlreadyThere,
            createdAt: Date(timeIntervalSince1970: 0),
        )
        assertSnapshot(of: host([.youtube], draft: draft), as: Self.image)
    }

    private func host(_ videos: [SpotVideo], draft: VideoDraft?) -> UIView {
        let section = SpotVideosSectionView(loader: Self.thumbnailLoader)
        section.show(videos, draft: draft)
        let width: CGFloat = 402
        let height = section.sizeThatFits(CGSize(width: width - 40, height: .greatestFiniteMagnitude)).height
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height + 40))
        container.backgroundColor = .systemBackground
        section.frame = CGRect(x: 20, y: 20, width: width - 40, height: height)
        container.addSubview(section)
        container.layoutIfNeeded()
        return container
    }
}

extension SpotVideo {
    fileprivate static let youtube = SpotVideo(
        id: "v1",
        spotID: "spot",
        provider: .youtube,
        url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        thumbnailURL: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg",
        caption: "Kickflip down the stairs",
        addedByID: "u1",
        addedByName: "Local Rider",
        position: 0,
    )

    fileprivate static let instagram = SpotVideo(
        id: "v2",
        spotID: "spot",
        provider: .instagram,
        url: "https://www.instagram.com/reel/C1aB2cD3eF4/",
        thumbnailURL: nil,
        caption: "",
        addedByID: nil,
        addedByName: nil,
        position: 1,
    )
}
