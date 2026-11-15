import ComponentKit
import PinLayout
import UIKit

final class WelcomeCardView: UIView {

    // MARK: Static Properties

    private static let mediaCornerRadius: CGFloat = 24

    // MARK: Properties

    private let mediaView: UIImageView
    private let titleLabel = Label()
    private let detailLabel = Label()

    // MARK: Lifecycle

    init(screenshot: OnboardingKitImages, title: String, detail: String) {
        mediaView = UIImageView(image: screenshot.image)
        super.init(frame: .zero)
        mediaView.contentMode = .scaleAspectFill
        mediaView.backgroundColor = .secondarySystemFill
        mediaView.layer.cornerRadius = Self.mediaCornerRadius
        mediaView.layer.cornerCurve = .continuous
        mediaView.clipsToBounds = true

        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .title3, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0

        detailLabel.text = detail
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0

        addSubview(mediaView)
        addSubview(titleLabel)
        addSubview(detailLabel)
        isAccessibilityElement = true
        accessibilityLabel = "\(title). \(detail)"
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
        mediaView.layer.borderWidth = 1 / max(traitCollection.displayScale, 1)
        mediaView.layer.borderColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: autoSizeThatFits(size) { layout(width: size.width) }.height)
    }

    // MARK: Functions

    private func layout(width: CGFloat) {
        mediaView.pin
            .top()
            .start()
            .size(width)
        titleLabel.pin
            .below(of: mediaView)
            .start()
            .width(width)
            .marginTop(16)
            .sizeToFit(.width)
        detailLabel.pin
            .below(of: titleLabel)
            .start()
            .width(width)
            .marginTop(4)
            .sizeToFit(.width)
    }
}
