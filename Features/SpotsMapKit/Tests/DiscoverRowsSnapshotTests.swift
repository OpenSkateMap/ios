import ComponentKit
import Foundation
import SnapshotTesting
import SpotModelKit
import Testing
import UIKit
@testable import SpotsMapKit

// MARK: - DiscoverRowsSnapshotTests

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct DiscoverRowsSnapshotTests {

    // MARK: Static Properties

    private static let width: CGFloat = 402
    private static let date = Date(timeIntervalSince1970: 1_791_590_400)

    // MARK: Lifecycle

    init() {
        // As the app sets it at launch.
        UIView.followLayoutDirection()
    }

    // MARK: Static Functions

    private static func rows(_ direction: UITraitEnvironmentLayoutDirection) -> UIView {
        let rows = UIView()
        rows.backgroundColor = .systemBackground
        rows.traitOverrides.displayScale = 1
        rows.traitOverrides.userInterfaceStyle = .light
        rows.traitOverrides.layoutDirection = direction
        let spot = SearchResultCell()
        spot.show(
            SpotIndex(
                id: "macba",
                title: "MACBA Plaza",
                kind: .plaza,
                condition: .skateable,
                cityID: "barcelona",
                latitude: 41.383,
                longitude: 2.167,
                version: 1,
            ),
            city: "Barcelona",
        )
        let place = SearchResultCell()
        place.show(placeTitle: "Barcelona", subtitle: "Catalonia, Spain")
        var y: CGFloat = 0
        for cell in [spot, place] {
            cell.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
            rows.addSubview(cell)
            let height = cell.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            cell.frame = CGRect(x: 0, y: y, width: width, height: height)
            y += height
        }
        let cards = CollectionCardsCell()
        cards.show([
            CollectionCard(collection: collection("favorites", "Favorites", kind: .favorites, color: .amber), spotCount: 4),
            CollectionCard(collection: collection("night", "Night Sessions", kind: .custom, color: .sky), spotCount: 2),
            CollectionCard(collection: collection("bowls", "Brixton Bowls", kind: .custom, color: .mint), spotCount: 1),
        ])
        rows.addSubview(cards)
        let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: 0, section: 0))
        attributes.size = CGSize(width: width, height: 0)
        let cardsHeight = cards.preferredLayoutAttributesFitting(attributes).size.height
        cards.frame = CGRect(x: 0, y: y + 12, width: width, height: cardsHeight)
        rows.frame = CGRect(x: 0, y: 0, width: width, height: cards.frame.maxY + 12)
        return rows
    }

    private static func collection(_ id: String, _ name: String, kind: CollectionKind, color: CollectionColor) -> SpotCollection {
        SpotCollection(
            id: id,
            name: name,
            about: "",
            visibility: .private,
            kind: kind,
            look: CollectionLook(color: color),
            role: .owner,
            ownerID: "rider",
            ownerName: "Local Rider",
            ownerUsername: "local_rider",
            memberCount: 0,
            coverKey: nil,
            coverThumbhash: nil,
            position: 0,
            createdAt: date,
            updatedAt: date,
        )
    }

    // MARK: Functions

    @Test(arguments: [UITraitEnvironmentLayoutDirection.leftToRight, .rightToLeft])
    func `a spot, a place and the collection cards run from the leading edge`(direction: UITraitEnvironmentLayoutDirection) {
        let rows = Self.rows(direction)
        assertSnapshot(
            of: rows,
            as: .image(
                precision: 0.995,
                perceptualPrecision: 0.98,
                size: rows.bounds.size,
                traits: UITraitCollection {
                    $0.displayScale = 1
                    $0.userInterfaceStyle = .light
                    $0.layoutDirection = direction
                },
            ),
            named: direction == .rightToLeft ? "right-to-left" : "left-to-right",
        )
    }
}
