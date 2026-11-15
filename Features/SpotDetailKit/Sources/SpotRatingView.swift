import ComponentKit
import PinLayout
import SpotModelKit
import UIKit

final class SpotRatingView: UIView {

    // MARK: Static Properties

    private static let spacing: CGFloat = 8

    // MARK: Properties

    var onVote: ((SpotVote) -> Void)?

    private let upButton = UIButton(configuration: .filled())
    private let downButton = UIButton(configuration: .filled())
    private let feedback = UISelectionFeedbackGenerator()
    private var mine = SpotVote.none

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupViews()
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        let width = (bounds.width - Self.spacing) / 2
        upButton.pin
            .vertically()
            .start()
            .width(width)
        downButton.pin
            .vertically()
            .end()
            .width(width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitting = upButton.sizeThatFits(CGSize(width: (size.width - Self.spacing) / 2, height: .greatestFiniteMagnitude))
        return CGSize(width: size.width, height: max(44, ceil(fitting.height)))
    }

    // MARK: Functions

    func show(up: Int, down: Int, mine: SpotVote, isEnabled: Bool) {
        self.mine = mine
        style(upButton, symbol: "hand.thumbsup", count: up, isMine: mine == .up)
        style(downButton, symbol: "hand.thumbsdown", count: down, isMine: mine == .down)
        upButton.accessibilityValue = SpotDetailKitStrings.Spot.Rating.A11y.votes(up)
        downButton.accessibilityValue = SpotDetailKitStrings.Spot.Rating.A11y.votes(down)
        upButton.isEnabled = isEnabled
        downButton.isEnabled = isEnabled
        setNeedsLayout()
    }

    private func setupViews() {
        upButton.accessibilityLabel = SpotDetailKitStrings.Spot.Rating.A11y.up
        downButton.accessibilityLabel = SpotDetailKitStrings.Spot.Rating.A11y.down
        for button in [upButton, downButton] {
            addSubview(button)
        }
    }

    private func setupActions() {
        upButton.addAction(UIAction { [weak self] _ in self?.vote(.up) }, for: .primaryActionTriggered)
        downButton.addAction(UIAction { [weak self] _ in self?.vote(.down) }, for: .primaryActionTriggered)
    }

    private func style(_ button: UIButton, symbol: String, count: Int, isMine: Bool) {
        var configuration = UIButton.Configuration.filled()
        configuration.cornerStyle = .capsule
        configuration.image = UIImage(systemName: isMine ? "\(symbol).fill" : symbol)
        configuration.imagePadding = 8
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .body, scale: .medium)
        configuration.title = count.formatted()
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .body, weight: .semibold)
            return attributes
        }
        configuration.baseBackgroundColor = isMine ? .tintColor : .tertiarySystemFill
        configuration.baseForegroundColor = isMine ? .white : .label
        button.configuration = configuration
        button.accessibilityTraits = isMine ? [.button, .selected] : .button
    }

    private func vote(_ vote: SpotVote) {
        feedback.selectionChanged()
        let button = vote == .up ? upButton : downButton
        if mine != vote, !UIAccessibility.isReduceMotionEnabled {
            button.imageView?.addSymbolEffect(.bounce, options: .nonRepeating)
        }
        onVote?(mine == vote ? .none : vote)
    }
}
