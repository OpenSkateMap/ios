public import UIKit

open class Label: UILabel {

    // MARK: Overridden Properties

    override open var text: String? {
        didSet {
            if text != oldValue {
                measured = nil
            }
        }
    }

    override open var attributedText: NSAttributedString? {
        didSet {
            if attributedText != oldValue {
                measured = nil
            }
        }
    }

    override open var font: UIFont! {
        didSet {
            if font != oldValue {
                measured = nil
            }
        }
    }

    /// Reads back the limit in effect: `linesAtAccessibilitySizes` at accessibility text sizes, when set.
    override open var numberOfLines: Int {
        get { super.numberOfLines }
        set {
            standardLines = newValue
            applyLines()
        }
    }

    override open var lineBreakMode: NSLineBreakMode {
        didSet {
            if lineBreakMode != oldValue {
                measured = nil
            }
        }
    }

    // MARK: Computed Properties

    public var textLayout: TextLayout {
        TextLayout(text: drawnText, numberOfLines: numberOfLines, lineBreakMode: lineBreakMode)
    }

    /// UILabel draws runs without a font (an attachment, a space beside it) in `font`; TextKit would measure them in Helvetica 12.
    private var drawnText: NSAttributedString {
        guard let attributedText, let font else {
            return attributedText ?? NSAttributedString()
        }
        let filled = NSMutableAttributedString(attributedString: attributedText)
        attributedText.enumerateAttribute(.font, in: NSRange(location: 0, length: attributedText.length)) { value, range, _ in
            if value == nil {
                filled.addAttribute(.font, value: font, range: range)
            }
        }
        return filled
    }

    // MARK: Properties

    /// The lines at accessibility text sizes, where a line cut short would hide what it says; `nil` keeps `numberOfLines`.
    public var linesAtAccessibilitySizes: Int? {
        didSet {
            applyLines()
        }
    }

    private var measured: (width: CGFloat, size: CGSize)?
    private var standardLines = 1

    // MARK: Lifecycle

    override public init(frame: CGRect) {
        super.init(frame: frame)

        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (label: Self, _) in
            label.measured = nil
            label.applyLines()
        }
    }

    @available(*, unavailable)
    public required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override open func sizeThatFits(_ size: CGSize) -> CGSize {
        // One line reports its whole width, as UILabel does: PinLayout's sizeToFit() asks at the current frame.
        let width = numberOfLines == 1 ? 0 : size.width
        if let measured, measured.width == width {
            return measured.size
        }
        let fitted = textLayout.size(fitting: width)
        measured = (width, fitted)
        return fitted
    }

    // MARK: Functions

    private func applyLines() {
        let lines = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? linesAtAccessibilitySizes ?? standardLines
            : standardLines
        guard lines != super.numberOfLines else {
            return
        }
        super.numberOfLines = lines
        measured = nil
    }
}
