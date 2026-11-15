import ComponentKit
import PeopleKit
import UIKit

extension HandleNetwork {

    // MARK: Static Properties

    private static let instagramGradient = [0xFFD600, 0xFF7A00, 0xFF0069, 0xD300C5, 0x7638FA].map(UIColor.init(rgb:))

    // MARK: Functions

    func tile(side: CGFloat = 29, traitCollection: UITraitCollection = .current) -> UIImage {
        switch self {
        case .instagram:
            .tile(
                glyph: ProfileKitAsset.instagramGlyph.image,
                fill: .gradient(Self.instagramGradient),
                side: side,
                glyphScale: 0.68,
                traitCollection: traitCollection,
            )

        case .tiktok:
            .tile(
                glyph: ProfileKitAsset.tiktok.image(
                    compatibleWith: traitCollection.modifyingTraits { $0.userInterfaceStyle = .dark }
                ),
                fill: .color(.black),
                side: side,
                glyphScale: 0.58,
                tintsGlyph: false,
                traitCollection: traitCollection,
            )

        case .youtube:
            .tile(
                glyph: ProfileKitAsset.youtubeGlyph.image,
                fill: .color(UIColor(rgb: 0xFF0000)),
                side: side,
                glyphScale: 0.62,
                traitCollection: traitCollection,
            )

        case .x:
            .tile(
                glyph: ProfileKitAsset.xGlyph.image,
                fill: .color(.black),
                side: side,
                glyphScale: 0.54,
                traitCollection: traitCollection,
            )

        case .telegram:
            .tile(
                glyph: ProfileKitAsset.telegramGlyph.image,
                fill: .color(UIColor(rgb: 0x26A5E4)),
                side: side,
                glyphScale: 0.58,
                traitCollection: traitCollection,
            )

        case .website:
            .symbolTile(systemName: "globe", color: .systemGray, side: side, traitCollection: traitCollection)
        }
    }

    func icon(side: CGFloat, traitCollection: UITraitCollection = .current) -> UIImage? {
        guard let logo = logoAsset?.image(compatibleWith: traitCollection) else {
            return UIImage(systemName: "globe", withConfiguration: UIImage.SymbolConfiguration(pointSize: side * 0.8))?
                .withTintColor(.label.resolvedColor(with: traitCollection), renderingMode: .alwaysOriginal)
        }
        let scale = min(side / logo.size.width, side / logo.size.height)
        let size = CGSize(width: logo.size.width * scale, height: logo.size.height * scale)
        let bounds = CGRect(origin: .zero, size: CGSize(width: side, height: side))
        let image = UIGraphicsImageRenderer(bounds: bounds, format: UIGraphicsImageRendererFormat(for: traitCollection))
            .image { _ in
                logo.draw(in: CGRect(
                    x: (side - size.width) / 2,
                    y: (side - size.height) / 2,
                    width: size.width,
                    height: size.height,
                ))
            }
        return image.withRenderingMode(.alwaysOriginal)
    }

    private var logoAsset: ProfileKitImages? {
        switch self {
        case .instagram: ProfileKitAsset.instagram
        case .tiktok: ProfileKitAsset.tiktok
        case .youtube: ProfileKitAsset.youtube
        case .x: ProfileKitAsset.x
        case .telegram: ProfileKitAsset.telegram
        case .website: nil
        }
    }

    var placeholder: String {
        self == .website ? "https://" : ProfileKitStrings.EditProfile.Handle.placeholder
    }

    func display(_ value: String) -> String {
        guard self == .website else {
            return prefix + value
        }
        return value.replacingOccurrences(of: #"^https?://(www\.)?"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

// MARK: - ProfileKitImages+Traits

extension ProfileKitImages {
    /// `image` alone resolves for the main screen's traits, not `traitCollection` (TikTok's and X's dark logos).
    fileprivate func image(compatibleWith traitCollection: UITraitCollection) -> UIImage {
        let base: UIImage = image
        return base.imageAsset?.image(with: traitCollection) ?? base
    }
}

// MARK: - UIColor+RGB

extension UIColor {
    fileprivate nonisolated convenience init(rgb: Int) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1,
        )
    }
}
