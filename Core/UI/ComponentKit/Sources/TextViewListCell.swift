import PinLayout
public import UIKit

public final class TextViewListCell: UICollectionViewListCell, UITextViewDelegate {

    // MARK: Properties

    public var onChange: ((String) -> Void)?
    public var minimumHeight: CGFloat = 44

    private let textView = UITextView().softEdges()
    private let placeholderLabel = Label()
    private var limit = 60

    // MARK: Lifecycle

    override public init(frame: CGRect) {
        super.init(frame: frame)

        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override public func layoutSubviews() {
        super.layoutSubviews()

        textView.pin
            .vertically(6)
            .horizontally(16)
        placeholderLabel.pin
            .top(14)
            .horizontally(16)
            .sizeToFit(.width)
    }

    override public func preferredLayoutAttributesFitting(_ attributes: UICollectionViewLayoutAttributes)
        -> UICollectionViewLayoutAttributes {
        let fitted = attributes.copy() as? UICollectionViewLayoutAttributes ?? attributes
        let height = textView.sizeThatFits(CGSize(width: attributes.size.width - 32, height: .greatestFiniteMagnitude)).height
        fitted.size.height = max(minimumHeight, ceil(height) + 12)
        return fitted
    }

    // MARK: Functions

    public func show(text: String,
                     placeholder: String,
                     limit: Int,
                     isMultiline: Bool,
                     isEnabled: Bool,
                     accessibilityLabel: String? = nil) {
        self.limit = limit
        textView.accessibilityLabel = accessibilityLabel
        textView.isEditable = isEnabled
        textView.textColor = isEnabled ? .label : .secondaryLabel
        if textView.text != text {
            textView.text = text
        }
        placeholderLabel.text = placeholder
        placeholderLabel.isHidden = !text.isEmpty
        textView.returnKeyType = isMultiline ? .default : .done
        textView.autocapitalizationType = isMultiline ? .sentences : .words
    }

    public func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = !textView.text.isEmpty
        onChange?(textView.text)
        // The list re-measures the cell (`selfSizingInvalidation`), so a description grows as it's typed.
        invalidateIntrinsicContentSize()
    }

    public func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard text != "\n" || textView.returnKeyType != .done else {
            textView.resignFirstResponder()
            return false
        }
        let next = (textView.text as NSString).replacingCharacters(in: range, with: text)
        return next.count <= limit
    }

    private func setupViews() {
        textView.font = .preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        textView.delegate = self
        placeholderLabel.font = .preferredFont(forTextStyle: .body)
        placeholderLabel.adjustsFontForContentSizeCategory = true
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.isUserInteractionEnabled = false
        contentView.addSubview(textView)
        contentView.addSubview(placeholderLabel)
    }
}
