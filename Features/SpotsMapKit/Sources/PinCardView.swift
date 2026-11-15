import ComponentKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

final class PinCardView: UIView {

    // MARK: Properties

    var isSelected = false {
        didSet {
            guard isSelected != oldValue else {
                return
            }
            frameView.image = PinArt.frame(selected: isSelected, scale: traitCollection.displayScale)
        }
    }

    private let frameView = UIImageView()
    private let photoView = UIImageView()
    private let glyphView = UIImageView()
    private var shown: (key: String?, thumbhash: String?, kind: SpotKind)?
    private let loader = PhotoLoader()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        photoView.layer.cornerRadius = PinArt.cornerRadius - PinArt.border
        photoView.layer.cornerCurve = .continuous
        glyphView.contentMode = .scaleAspectFit
        glyphView.tintColor = .white
        glyphView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        for subview in [frameView, photoView, glyphView] {
            addSubview(subview)
        }
        frameView.image = PinArt.frame(selected: false, scale: traitCollection.displayScale)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        frameView.pin
            .all(-PinArt.shadowInset)
        photoView.pin
            .all(PinArt.border)
        glyphView.pin
            .center()
            .size(24)
    }

    // MARK: Functions

    func show(_ spot: SpotIndex) {
        if let shown, shown.key == spot.coverKey, shown.thumbhash == spot.coverThumbhash, shown.kind == spot.kind {
            return
        }
        reset()
        shown = (spot.coverKey, spot.coverThumbhash, spot.kind)
        photoView.backgroundColor = spot.kind.tint
        guard spot.coverKey != nil || spot.coverThumbhash != nil else {
            glyphView.image = UIImage(systemName: spot.kind.symbolName)
            return
        }
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 3
        loader.show(key: spot.coverKey, thumbhash: spot.coverThumbhash, size: .pin, scale: scale, in: photoView)
    }

    func reset() {
        loader.cancel()
        shown = nil
        photoView.image = nil
        glyphView.image = nil
    }
}
