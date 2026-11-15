import ComponentKit
import PinLayout
import UIKit

final class SheetTextEditorView: UIView, UITextViewDelegate {

    // MARK: Computed Properties

    var text: String {
        textView.text ?? ""
    }

    // MARK: Properties

    private let textView = UITextView().softEdges()
    private let placeholderLabel = Label()
    private let countLabel = Label()
    private let limit: Int

    // MARK: Lifecycle

    init(text: String, placeholder: String, limit: Int) {
        self.limit = limit
        super.init(frame: .zero)
        backgroundColor = .tertiarySystemFill
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        textView.text = text
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        textView.delegate = self
        textView.accessibilityLabel = placeholder
        placeholderLabel.text = placeholder
        placeholderLabel.font = .preferredFont(forTextStyle: .body)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.isAccessibilityElement = false
        countLabel.font = .preferredFont(forTextStyle: .caption1)
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.textColor = .secondaryLabel
        for view in [textView, placeholderLabel, countLabel] {
            addSubview(view)
        }
        update()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateProperties() {
        super.updateProperties()

        countLabel.textAlignment = traitCollection.trailingTextAlignment
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        let countHeight = ceil(countLabel.font.lineHeight)
        textView.pin
            .top()
            .bottom(countHeight + 8)
            .horizontally()
        placeholderLabel.pin
            .top(14)
            .horizontally(17)
            .sizeToFit(.width)
        countLabel.pin
            .bottom(8)
            .horizontally(16)
            .height(countHeight)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let lines = ceil((textView.font ?? .preferredFont(forTextStyle: .body)).lineHeight * 4)
        return CGSize(width: size.width, height: max(170, lines + 28 + ceil(countLabel.font.lineHeight) + 8))
    }

    override func becomeFirstResponder() -> Bool {
        textView.becomeFirstResponder()
    }

    // MARK: Functions

    func textViewDidChange(_: UITextView) {
        update()
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let current = textView.text as NSString
        return current.replacingCharacters(in: range, with: text).count <= limit
    }

    private func update() {
        placeholderLabel.isHidden = !text.isEmpty
        countLabel.text = ContributeKitStrings.SheetTextEditor.count(text.count, limit)
    }
}
