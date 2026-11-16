import ComponentKit
import ContributionsKit
import ImageKit
import SnapshotTesting
import SpotModelKit
import Testing
import UIKit
@testable import ContributeKit

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct AddVideoSheetTests {

    // MARK: Static Properties

    private static var image: Snapshotting<UIView, UIImage> {
        .image(precision: 0.995, perceptualPrecision: 0.98, traits: UITraitCollection { $0.displayScale = 1 })
    }

    // MARK: Lifecycle

    init() {
        // As the app sets it at launch.
        UIView.followLayoutDirection()
    }

    // MARK: Functions

    @Test(.tags(.snapshot))
    func `a YouTube video that plays shows its title and can be sent`() async {
        let content = AddVideoContentView(
            model: AddVideoModel(checker: VideoLinkChecker { _ in .available(
                title: "Kickflip down the stairs",
                author: "Local Rider",
            ) }),
            loader: .placeholder,
        )
        content.linkText = "https://youtu.be/dQw4w9WgXcQ?si=share"
        await content.model.settle()
        #expect(content.link?.externalID == "dQw4w9WgXcQ")
        assertSnapshot(of: host(content), as: Self.image)
    }

    @Test(.tags(.snapshot))
    func `a video YouTube doesn't have says so and can't be sent`() async {
        let content = AddVideoContentView(
            model: AddVideoModel(checker: VideoLinkChecker { _ in .unavailable }),
            loader: .placeholder,
        )
        content.linkText = "https://www.youtube.com/watch?v=aaaaaaaaaaa"
        await content.model.settle()
        #expect(content.link == nil)
        assertSnapshot(of: host(content), as: Self.image)
    }

    @Test(.tags(.snapshot))
    func `anything else says it isn't a video link and can't be sent`() {
        let content = AddVideoContentView(model: AddVideoModel(checker: .preview), loader: .placeholder)
        content.linkText = "https://vimeo.com/123"
        #expect(content.link == nil)
        assertSnapshot(of: host(content), as: Self.image)
    }

    @Test
    func `the same video keeps its answer, and a different one is asked about`() async {
        let (asked, ask) = AsyncStream.makeStream(of: String.self)
        let model = AddVideoModel(checker: VideoLinkChecker { link in
            ask.yield(link.externalID)
            return .available(title: link.externalID, author: nil)
        })
        model.setLinkText("https://youtu.be/dQw4w9WgXcQ")
        await model.settle()
        model.setLinkText("https://youtu.be/dQw4w9WgXcQ?t=42")
        model.setLinkText("https://youtu.be/9bZkp7q19f0")
        await model.settle()
        ask.finish()
        var askedAbout = [String]()
        for await id in asked {
            askedAbout.append(id)
        }
        #expect(askedAbout == ["dQw4w9WgXcQ", "9bZkp7q19f0"])
        #expect(model.sendableLink?.externalID == "9bZkp7q19f0")
    }

    @Test
    func `a newer link replaces a check still under way`() async {
        let (release, open) = AsyncStream.makeStream(of: Void.self)
        let model = AddVideoModel(checker: VideoLinkChecker { link in
            if link.externalID == "dQw4w9WgXcQ" {
                for await _ in release {
                    break
                }
            }
            return .available(title: link.externalID, author: nil)
        })
        model.setLinkText("https://youtu.be/dQw4w9WgXcQ")
        model.setLinkText("https://youtu.be/9bZkp7q19f0")
        open.yield()
        await model.settle()
        #expect(model.sendableLink?.externalID == "9bZkp7q19f0")
    }

    @Test
    func `a link still being typed isn't called invalid until the field is left`() {
        let model = AddVideoModel(checker: .preview)
        model.setLinkText("https://yout", isEditing: true)
        #expect(model.state == .unfinished)
        model.setLinkText("https://yout")
        #expect(model.state == .invalid)
    }

    @Test
    func `a link that couldn't be checked can still be sent`() async {
        let model = AddVideoModel(checker: .preview)
        model.setLinkText("https://www.instagram.com/reel/C1a2b3c4d5e/")
        await model.settle()
        #expect(model.sendableLink?.provider == .instagram)
    }

    private func host(_ content: AddVideoContentView) -> UIView {
        let width: CGFloat = 402
        content.updatePropertiesIfNeeded()
        let height = content.sizeThatFits(CGSize(width: width - 40, height: .greatestFiniteMagnitude)).height
        let container = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height + 40))
        container.backgroundColor = .systemBackground
        content.frame = CGRect(x: 20, y: 20, width: width - 40, height: height)
        container.addSubview(content)
        container.layoutIfNeeded()
        return container
    }
}
