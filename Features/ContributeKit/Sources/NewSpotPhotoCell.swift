import ComponentKit
import PinLayout
import UIKit

final class NewSpotPhotoCell: UICollectionViewCell {

    // MARK: Static Properties

    private static let removeSide: CGFloat = 24

    // MARK: Properties

    let photoView = NewSpotPhotoView()
    var onRemove: (() -> Void)?
    var isVideo = false {
        didSet {
            removeButton.accessibilityLabel = PhotoCreditEditorView.removeTitle(isVideo: isVideo)
        }
    }

    private let removeButton = UIButton(configuration: .plain())

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(
            systemName: "xmark",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .bold),
        )
        configuration.baseForegroundColor = .label
        configuration.background.visualEffect = UIBlurEffect(style: .systemThickMaterial)
        configuration.cornerStyle = .capsule
        removeButton.configuration = configuration
        removeButton.accessibilityLabel = ContributeKitStrings.PhotoCredit.remove
        removeButton.alpha = 0
        removeButton.addAction(UIAction { [weak self] _ in self?.onRemove?() }, for: .primaryActionTriggered)
        contentView.addSubview(photoView)
        contentView.addSubview(removeButton)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        photoView.pin
            .all()
        // Over the top trailing corner, half outside a thumbnail, as the Home Screen's remove buttons sit.
        let inset: CGFloat = bounds.width > NewSpotPhotoView.coverWidth ? 10 : 0
        removeButton.pin
            .top(inset - Self.removeSide / 2)
            .end(inset - Self.removeSide / 2)
            .size(Self.removeSide)
    }

    /// The remove button reaches past the cell's bounds, where the content view's own hit test never looks.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if removeButton.alpha > 0, removeButton.point(inside: convert(point, to: removeButton), with: event) {
            return removeButton
        }
        return super.hitTest(point, with: event)
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        contentView.alpha = 1
        Jiggle.stop(on: contentView.layer)
    }

    // MARK: Functions

    func setArranging(_ isArranging: Bool, animated: Bool) {
        if isArranging {
            Jiggle.start(on: contentView.layer, side: bounds.width)
        } else {
            Jiggle.stop(on: contentView.layer)
        }
        let changes = { self.removeButton.alpha = isArranging ? 1 : 0 }
        if animated {
            UIView.animate(withDuration: 0.2, animations: changes)
        } else {
            changes()
        }
    }
}
