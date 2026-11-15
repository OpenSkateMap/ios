import ComponentKit
import UIKit

final class CopyableLabel: Label {

    // MARK: Overridden Properties

    override var canBecomeFirstResponder: Bool {
        isCopyable
    }

    // MARK: Properties

    var isCopyable = true {
        didSet {
            isUserInteractionEnabled = isCopyable
            accessibilityCustomActions = isCopyable ? [copyAction] : nil
        }
    }

    private let editMenu = UIEditMenuInteraction(delegate: nil)
    private let copyActionName: String
    private lazy var copyAction = UIAccessibilityCustomAction(name: copyActionName) { [weak self] _ in
        self?.copy(nil)
        return true
    }

    // MARK: Lifecycle

    init(copyActionName: String) {
        self.copyActionName = copyActionName
        super.init(frame: .zero)
        isUserInteractionEnabled = true
        // Text with a Copy action, not a button: the long press would make VoiceOver call it one.
        accessibilityTraits = .staticText
        accessibilityCustomActions = [copyAction]
        addInteraction(editMenu)
        addGestureRecognizer(UILongPressGestureRecognizer(target: self, action: #selector(showEditMenu(_:))))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func canPerformAction(_ action: Selector, withSender _: Any?) -> Bool {
        isCopyable && action == #selector(copy(_:))
    }

    override func copy(_: Any?) {
        UIPasteboard.general.string = text
    }

    // MARK: Functions

    @objc
    private func showEditMenu(_ press: UILongPressGestureRecognizer) {
        guard press.state == .began, becomeFirstResponder() else {
            return
        }
        // Over the text itself, which can be much narrower than the label.
        let shown = textRect(forBounds: bounds, limitedToNumberOfLines: numberOfLines)
        editMenu.presentEditMenu(with: UIEditMenuConfiguration(
            identifier: nil,
            sourcePoint: CGPoint(x: shown.midX, y: shown.minY),
        ))
    }
}
