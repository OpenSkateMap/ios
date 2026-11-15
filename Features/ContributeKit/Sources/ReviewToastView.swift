import ComponentKit
import PinLayout
import UIKit

/// The bar with Undo after a decision, near the thumb; failures go to `ToastView`, so they never take Undo away.
final class ReviewToastView: UIView {

    // MARK: Computed Properties

    private var messageTrailing: CGFloat {
        if isUndoing {
            return spinner.bounds.width + 28
        }
        return undoButton.intrinsicContentSize.width + 16
    }

    // MARK: Properties

    var onUndo: (() -> Void)?

    private(set) var isUndoing = false

    private let effectView = UIVisualEffectView(effect: UIGlassEffect())
    private let messageLabel = Label()
    private let undoButton = UIButton(configuration: .plain())
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var ending: Task<Void, Never>?

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        effectView.layer.cornerCurve = .continuous
        effectView.clipsToBounds = true
        messageLabel.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 2
        undoButton.configuration?.title = ContributeKitStrings.ReviewToast.undo
        undoButton.configuration?.baseForegroundColor = .tintColor
        undoButton.addAction(UIAction { [weak self] _ in self?.undo() }, for: .primaryActionTriggered)
        spinner.hidesWhenStopped = true
        addSubview(effectView)
        effectView.contentView.addSubview(messageLabel)
        effectView.contentView.addSubview(undoButton)
        effectView.contentView.addSubview(spinner)
        isAccessibilityElement = false
        alpha = 0
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        ending?.cancel()
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        effectView.pin
            .all()
        effectView.layer.cornerRadius = bounds.height / 2
        undoButton.pin
            .vCenter()
            .end(8)
            .sizeToFit()
        spinner.pin
            .vCenter()
            .end(20)
            .sizeToFit()
        messageLabel.pin
            .vCenter()
            .start(20)
            .end(messageTrailing)
            .sizeToFit(.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelWidth = size.width - 20 - messageTrailing
        let label = messageLabel.sizeThatFits(CGSize(width: max(labelWidth, 0), height: .greatestFiniteMagnitude))
        return CGSize(width: size.width, height: max(52, ceil(label.height) + 24))
    }

    // MARK: Functions

    func show(_ message: String, for seconds: Double, onEnd: @escaping () -> Void) {
        isUndoing = false
        spinner.stopAnimating()
        messageLabel.text = message
        undoButton.isHidden = false
        superview?.setNeedsLayout()
        setNeedsLayout()
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
        UIAccessibility.post(notification: .announcement, argument: message)
        ending?.cancel()
        ending = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else {
                return
            }
            self?.hide()
            onEnd()
        }
    }

    func finishUndoing() {
        guard isUndoing else {
            return
        }
        isUndoing = false
        spinner.stopAnimating()
        hide()
    }

    private func undo() {
        ending?.cancel()
        isUndoing = true
        messageLabel.text = ContributeKitStrings.ReviewToast.undoing
        undoButton.isHidden = true
        spinner.startAnimating()
        superview?.setNeedsLayout()
        setNeedsLayout()
        UIAccessibility.post(notification: .announcement, argument: ContributeKitStrings.ReviewToast.undoing)
        onUndo?()
    }

    private func hide() {
        UIView.animate(withDuration: 0.2) { self.alpha = 0 }
    }
}
