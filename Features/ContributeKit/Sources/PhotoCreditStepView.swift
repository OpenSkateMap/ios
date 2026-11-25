import ComponentKit
import PinLayout
import UIKit

/// One photo of a pick while going through them: the photo with its place in the pick on it, as the review card shows
/// a spot's photos, and who took it under it.
final class PhotoCreditStepView: UIView {

    // MARK: Properties

    var onChange: (() -> Void)?

    let editor = PhotoCreditEditorView(credit: NewSpotForm.Credit(), for: .step)

    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let pageLabel = InsetLabel()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        imageView.backgroundColor = .tertiarySystemFill
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 20
        imageView.layer.cornerCurve = .continuous
        imageView.clipsToBounds = true
        pageLabel.font = .preferredFont(forTextStyle: .caption1, weight: .semibold)
        pageLabel.adjustsFontForContentSizeCategory = true
        pageLabel.textColor = .white
        pageLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        pageLabel.layer.cornerRadius = 10
        pageLabel.clipsToBounds = true
        editor.onChange = { [weak self] in self?.onChange?() }
        for view in [imageView, spinner, pageLabel, editor] {
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

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    func show(_ image: UIImage?, isPreparing: Bool) {
        imageView.image = image
        if isPreparing {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
    }

    func show(page: Int, of count: Int, credit: NewSpotForm.Credit, isVideo: Bool) {
        pageLabel.text = ContributeKitStrings.ReviewCard.page(page, count)
        editor.isVideo = isVideo
        editor.show(credit)
        setNeedsLayout()
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        imageView.pin
            .top()
            .start()
            .width(width)
            .height((width * 0.75).rounded())
        spinner.pin
            .center(to: imageView.anchor.center)
        pageLabel.pin
            .bottomEnd(to: imageView.anchor.bottomEnd)
            .margin(12)
            .sizeToFit()
        let editorHeight = editor.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        editor.pin
            .below(of: imageView)
            .start()
            .width(width)
            .height(editorHeight)
            .marginTop(16)
        return editor.frame.maxY
    }
}
