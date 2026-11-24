import ComponentKit
import ImageKit
import PinLayout
import UIKit

/// A photo of New Spot: the cover's look at the cover's size and a thumbnail's below it, so the copy a person drags
/// can grow into the cover's place or shrink out of it.
final class NewSpotPhotoView: UIView {

    // MARK: Types

    struct Content {
        /// One of the spot's own photos, loaded by its key; otherwise `image`.
        struct Remote: Equatable {
            var key: String
            var thumbhash: String
            /// The screen's, from the view that made the content: the lifted copy isn't in a window yet.
            var scale: CGFloat
        }

        var image: UIImage?
        var remote: Remote?
        var isPreparing = false
        var problem: (text: String, color: UIColor)?
        var credit: String?
        var clipMilliseconds: Int?
    }

    // MARK: Static Properties

    /// Wider than this, a photo is the cover.
    static let coverWidth: CGFloat = 120

    // MARK: Computed Properties

    private var isCover: Bool {
        bounds.width > Self.coverWidth
    }

    // MARK: Properties

    var content = Content() {
        didSet {
            show()
        }
    }

    /// Room the cover leaves at its bottom trailing corner for the add button.
    var trailingInset: CGFloat = 0 {
        didSet {
            setNeedsLayout()
        }
    }

    private let imageView = UIImageView()
    private let loader = PhotoLoader()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let problemLabel = InsetLabel()
    private let creditLabel = InsetLabel()
    private let clipBadge = ClipBadgeView()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .tertiarySystemFill
        layer.cornerCurve = .continuous
        clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        problemLabel.font = .preferredFont(forTextStyle: .footnote, weight: .semibold)
        problemLabel.adjustsFontForContentSizeCategory = true
        problemLabel.textColor = .white
        problemLabel.layer.cornerRadius = 11
        problemLabel.layer.cornerCurve = .continuous
        problemLabel.clipsToBounds = true
        creditLabel.textColor = .white
        creditLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        creditLabel.clipsToBounds = true
        clipBadge.isHidden = true
        for view in [imageView, spinner, problemLabel, creditLabel, clipBadge] {
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        let isCover = isCover
        layer.cornerRadius = isCover ? 28 : 14
        layer.borderWidth = !isCover && content.problem != nil ? 3 : 0
        problemLabel.isHidden = !isCover || content.problem == nil
        creditLabel.isHidden = content.problem != nil || content.credit == nil
        creditLabel.font = .preferredFont(forTextStyle: isCover ? .caption1 : .caption2, weight: .semibold)
        creditLabel.insets = isCover
            ? NSDirectionalEdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7)
            : NSDirectionalEdgeInsets(top: 1, leading: 5, bottom: 1, trailing: 5)
        creditLabel.layer.cornerRadius = isCover ? 10 : 7
        imageView.pin
            .all()
        spinner.pin
            .center()
        problemLabel.pin
            .bottom(12)
            .hCenter()
            .sizeToFit()
        let margin: CGFloat = isCover ? 12 : 4
        clipBadge.isCompact = !isCover
        clipBadge.pin
            .bottom(margin)
            .start(margin)
            .sizeToFit()
        creditLabel.pin
            .bottom(clipBadge.isHidden ? margin : bounds.height - clipBadge.frame.minY + (isCover ? 6 : 2))
            .start(margin)
            .maxWidth(bounds.width - 2 * margin - (isCover ? trailingInset : 0))
            .sizeToFit()
    }

    // MARK: Functions

    private func show() {
        if let remote = content.remote {
            loader.show(key: remote.key, thumbhash: remote.thumbhash, size: .card, scale: remote.scale, in: imageView)
        } else {
            loader.cancel()
            imageView.image = content.image
        }
        if content.isPreparing {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
        problemLabel.text = content.problem?.text
        problemLabel.backgroundColor = content.problem?.color
        layer.borderColor = content.problem?.color.cgColor
        creditLabel.text = content.credit
        clipBadge.isHidden = content.clipMilliseconds == nil
        clipBadge.milliseconds = content.clipMilliseconds ?? 0
        setNeedsLayout()
    }
}
