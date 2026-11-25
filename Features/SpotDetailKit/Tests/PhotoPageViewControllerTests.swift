import CustomDump
import Testing
import UIKit
@testable import SpotDetailKit

// MARK: - PhotoPageViewControllerTests

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PhotoPageViewControllerTests {

    // MARK: Static Properties

    /// An iPhone 17 Pro Max held upright.
    private static let screen = CGRect(x: 0, y: 0, width: 440, height: 956)

    // MARK: Helpers

    private static func page(showing size: CGSize) -> PhotoPageViewController {
        let image = UIGraphicsImageRenderer(
            size: size,
            format: UIGraphicsImageRendererFormat(for: UITraitCollection(displayScale: 1)),
        )
        .image { _ in }
        let page = PhotoPageViewController(
            photo: GalleryPhoto(key: nil, thumbhash: nil, credit: nil, addedAt: nil, clip: nil),
            index: 0,
            placeholder: image,
            scale: 1,
            clipPlayback: ClipPlayback(cache: nil),
        )
        page.view.frame = screen
        return page
    }

    // MARK: Tests

    @Test
    func `a 9:16 photo fills the screen, as a clip does`() {
        let page = Self.page(showing: CGSize(width: 1080, height: 1920))
        expectNoDifference(page.photoFrame(in: page.view), Self.screen)
        #expect(page.fillsScreen)
    }

    @Test
    func `a 3:2 photo fits the screen, centred`() throws {
        let page = Self.page(showing: CGSize(width: 1080, height: 720))
        let frame = try #require(page.photoFrame(in: page.view))
        expectNoDifference(CGSize(width: frame.width.rounded(), height: frame.height.rounded()), CGSize(width: 440, height: 293))
        #expect(abs(frame.midY - Self.screen.midY) < 1)
        #expect(!page.fillsScreen)
    }
}
