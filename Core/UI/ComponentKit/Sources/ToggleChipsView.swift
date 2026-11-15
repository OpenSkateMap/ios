import PinLayout
public import UIKit

public final class ToggleChipsView: UIView {

    // MARK: Static Properties

    /// A small button is 27 pt tall; HIG's minimum tap target is 28, and chips are tapped in quick runs.
    private static let minimumHeight: CGFloat = 32

    // MARK: Properties

    private let buttons: [UIButton]
    private let values: [String]
    private let isSelected: (String) -> Bool

    // MARK: Lifecycle

    public init(values: [String],
                title: (String) -> String = { $0 },
                isSelected: @escaping (String) -> Bool,
                onToggle: @escaping (String) -> Void) {
        self.values = values
        self.isSelected = isSelected
        buttons = values.map { value in
            // Filled: the gray style draws its base colour faintly, which turns a dark "selected" fill pale.
            var configuration = UIButton.Configuration.filled()
            configuration.title = title(value)
            configuration.cornerStyle = .capsule
            configuration.buttonSize = .small
            configuration.automaticallyUpdateForSelection = false
            let button = UIButton(configuration: configuration)
            button.changesSelectionAsPrimaryAction = true
            button.isSelected = isSelected(value)
            button.configurationUpdateHandler = { button in
                button.configuration?.baseBackgroundColor = button.isSelected ? .label : .secondarySystemFill
                // Not `.systemBackground`: on a sheet it resolves translucent and a selected chip's title vanishes.
                button.configuration?.baseForegroundColor = button.isSelected ? .inverseLabel : .label
            }
            button.addAction(
                UIAction { action in
                    if let chip = action.sender as? UIView {
                        UISelectionFeedbackGenerator(view: chip).selectionChanged()
                    }
                    onToggle(value)
                },
                for: .primaryActionTriggered,
            )
            return button
        }
        super.init(frame: .zero)
        for button in buttons {
            addSubview(button)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override public func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    public func refresh() {
        for (button, value) in zip(buttons, values) {
            button.isSelected = isSelected(value)
        }
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        let sizes = buttons.map { button in
            var size = button.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            size.height = max(size.height, Self.minimumHeight)
            return size
        }
        let frames = FlowLayout.frames(for: sizes, width: width, spacing: 8)
        for (button, frame) in zip(buttons, frames) {
            button.pin
                .top(frame.minY)
                .start(frame.minX)
                .size(frame.size)
        }
        return frames.map(\.maxY).max() ?? 0
    }
}
