import ComponentKit
import PeopleKit
import SnapshotTesting
import Testing
import UIKit
@testable import ProfileKit

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)), .tags(.snapshot))
struct SettingsTileTests {

    // MARK: Static Properties

    /// iPhone 17 Pro.
    private static let width: CGFloat = 402
    private static let rowHeight: CGFloat = 52

    // MARK: Lifecycle

    init() {
        // As the app sets it at launch.
        UIView.followLayoutDirection()
    }

    private static func rows(_ style: UIUserInterfaceStyle) -> (UIView, Snapshotting<UIView, UIImage>) {
        let traits = UITraitCollection {
            $0.displayScale = 2
            $0.userInterfaceStyle = style
            $0.preferredContentSizeCategory = .large
        }
        let view = rows(traits: traits)
        return (view, .image(precision: 0.995, perceptualPrecision: 0.98, size: view.bounds.size, traits: traits))
    }

    private static func rows(traits: UITraitCollection) -> UIView {
        let filled: [HandleNetwork: String] = [.instagram: "ertembiyik", .x: "ertembiyik", .website: "openskatemap.app"]
        var contents = HandleNetwork.allCases.map { network in
            var content = UIListContentConfiguration.valueCell()
            content.image = network.tile(traitCollection: traits)
            content.text = network.title
            content.secondaryText = filled[network].map { network.display($0) } ?? "Add"
            return content
        }
        let account: [(String, UIColor, String)] = [
            ("apple.logo", .black, "Using Sign in with Apple"),
            ("hand.raised.fill", .systemBlue, "Blocked Users"),
            ("rectangle.portrait.and.arrow.right", .systemGray, "Sign Out"),
            ("trash.fill", .systemRed, "Delete Account"),
        ]
        for (symbol, color, title) in account {
            var content = UIListContentConfiguration.cell()
            content.image = .symbolTile(systemName: symbol, color: color, traitCollection: traits)
            content.text = title
            contents.append(content)
        }
        let height = rowHeight * CGFloat(contents.count) + 32
        let view = UIView(frame: CGRect(x: 0, y: 0, width: width, height: height))
        view.backgroundColor = .systemGroupedBackground
        let card = UIView(frame: CGRect(x: 16, y: 16, width: width - 32, height: height - 32))
        card.backgroundColor = .secondarySystemGroupedBackground
        card.layer.cornerRadius = 26
        card.layer.cornerCurve = .continuous
        view.addSubview(card)
        for (index, content) in contents.enumerated() {
            let row = UIListContentView(configuration: content)
            row.frame = CGRect(x: 0, y: rowHeight * CGFloat(index), width: card.bounds.width, height: rowHeight)
            card.addSubview(row)
        }
        return view
    }

    // MARK: Functions

    @Test
    func `links and account rows show app-icon tiles in light`() {
        let (view, strategy) = Self.rows(.light)
        assertSnapshot(of: view, as: strategy)
    }

    @Test
    func `links and account rows show app-icon tiles in dark`() {
        let (view, strategy) = Self.rows(.dark)
        assertSnapshot(of: view, as: strategy)
    }

}
