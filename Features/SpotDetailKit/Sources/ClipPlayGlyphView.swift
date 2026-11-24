import PinLayout
import UIKit

/// Marks a photo whose clip isn't playing by itself (Auto-Play Video Previews off, or Low Power Mode).
final class ClipPlayGlyphView: UIVisualEffectView {

    // MARK: Properties

    private let glyph = UIImageView(image: UIImage(systemName: "play.fill"))

    // MARK: Lifecycle

    init() {
        super.init(effect: UIGlassEffect())

        cornerConfiguration = .capsule()
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        glyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        glyph.tintColor = .label
        glyph.contentMode = .center
        contentView.addSubview(glyph)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        glyph.pin
            .all()
    }
}
