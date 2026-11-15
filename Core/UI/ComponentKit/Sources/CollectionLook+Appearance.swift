public import SpotModelKit
public import UIKit

extension CollectionColor {
    public func tones(for traits: UITraitCollection) -> (center: UIColor, edge: UIColor) {
        let (center, edge) = baseTones
        return (center.resolvedColor(with: traits), edge.resolvedColor(with: traits))
    }

    private var baseTones: (UIColor, UIColor) {
        switch self {
        case .blue: Self.solid(.systemBlue)
        case .green: Self.solid(.systemGreen)
        case .orange: Self.solid(.systemOrange)
        case .red: Self.solid(.systemRed)
        case .purple: Self.solid(.systemPurple)
        case .teal: Self.solid(.systemTeal)
        case .pink: Self.solid(.systemPink)
        case .gray: Self.solid(.systemGray)
        case .sky: (.systemCyan, .systemBlue)
        case .lime: (.systemYellow, .systemGreen)
        case .amber: (.systemYellow, .systemOrange)
        case .coral: (.systemOrange, .systemRed)
        case .violet: (.systemPink, .systemPurple)
        case .mint: (.systemMint, .systemTeal)
        case .rose: (.systemPink.mixed(with: .white, amount: 0.3), .systemPink)
        case .silver: (.systemGray3, .systemGray)
        }
    }

    private static func solid(_ color: UIColor) -> (UIColor, UIColor) {
        (UIColor { color.resolvedColor(with: $0).mixed(with: .white, amount: 0.22) }, color)
    }
}

extension CollectionKind {
    public func title(named name: String) -> String {
        switch self {
        case .favorites: ComponentKitStrings.Collection.favorites
        case .custom: name
        }
    }

    public var pictureSymbol: String {
        switch self {
        case .favorites: "star.fill"
        case .custom: "rectangle.stack.fill"
        }
    }
}
