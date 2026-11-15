import PinLayout
import UIKit

final class FormFieldRowView: UIView {

    // MARK: Properties

    let textField = UITextField()

    // MARK: Lifecycle

    init(placeholder: String) {
        super.init(frame: .zero)

        textField.placeholder = placeholder
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.clearButtonMode = .whileEditing
        textField.returnKeyType = .done
        // An empty action is enough: `.editingDidEndOnExit` with any target makes Return resign the field.
        textField.addAction(UIAction { _ in }, for: .editingDidEndOnExit)
        addSubview(textField)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        textField.pin
            .vertically(4)
            .horizontally(16)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: max(56, textField.sizeThatFits(.zero).height + 24))
    }
}
