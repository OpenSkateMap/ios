import ComponentKit
import PeopleKit
import PinLayout
import UIKit

final class HandleChipsView: UIView {

    // MARK: Properties

    var onOpen: ((URL) -> Void)?

    private var buttons = [UIButton]()

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    func show(_ handles: Handles) {
        for button in buttons {
            button.removeFromSuperview()
        }
        buttons = handles.filled.compactMap { network, value in
            guard let url = network.url(for: value) else {
                return nil
            }
            var configuration = UIButton.Configuration.gray()
            configuration.cornerStyle = .capsule
            configuration.image = network.icon(side: 16, traitCollection: traitCollection)
            configuration.imagePadding = 6
            configuration.title = network.display(value)
            configuration.titleLineBreakMode = .byTruncatingMiddle
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = .preferredFont(forTextStyle: .footnote, weight: .semibold)
                return attributes
            }
            let button = UIButton(configuration: configuration)
            button.accessibilityLabel = ProfileKitStrings.HandleChips.A11y.label(network.title, network.display(value))
            button.accessibilityHint = ProfileKitStrings.HandleChips.A11y.hint(network.title)
            button.addAction(UIAction { [weak self] _ in self?.onOpen?(url) }, for: .primaryActionTriggered)
            addSubview(button)
            return button
        }
        setNeedsLayout()
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        let sizes = buttons.map { button in
            var size = button.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            size.width = min(size.width, width)
            return size
        }
        let frames = FlowLayout.frames(for: sizes, width: width, spacing: 8, centered: true)
        for (button, frame) in zip(buttons, frames) {
            button.pin
                .top(frame.minY)
                .start(frame.minX)
                .size(frame.size)
        }
        return frames.map(\.maxY).max() ?? 0
    }
}
