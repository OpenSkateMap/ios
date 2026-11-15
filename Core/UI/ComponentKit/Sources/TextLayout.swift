public import UIKit

public struct TextLayout {

    // MARK: Properties

    public let text: NSAttributedString
    public let numberOfLines: Int
    public let lineBreakMode: NSLineBreakMode

    // MARK: Lifecycle

    public init(text: NSAttributedString, numberOfLines: Int = 0, lineBreakMode: NSLineBreakMode = .byTruncatingTail) {
        self.text = text
        self.numberOfLines = numberOfLines
        self.lineBreakMode = lineBreakMode
    }

    /// A paragraph style that truncates makes TextKit lay out one line per paragraph; the container truncates instead.
    private static func wrappingByWord(_ text: NSAttributedString) -> NSAttributedString {
        let wrapped = NSMutableAttributedString(attributedString: text)
        text.enumerateAttribute(.paragraphStyle, in: NSRange(location: 0, length: text.length)) { value, range, _ in
            guard let style = value as? NSParagraphStyle, style.lineBreakMode != .byWordWrapping,
                  let copy = style.mutableCopy() as? NSMutableParagraphStyle else {
                return
            }
            copy.lineBreakMode = .byWordWrapping
            wrapped.addAttribute(.paragraphStyle, value: copy, range: range)
        }
        return wrapped
    }

    // MARK: Functions

    public func size(fitting width: CGFloat) -> CGSize {
        guard text.length > 0 else {
            return .zero
        }
        let storage = NSTextStorage(attributedString: Self.wrappingByWord(text))
        let layoutManager = NSLayoutManager()
        layoutManager.usesFontLeading = false
        let container = NSTextContainer(size: CGSize(
            width: width > 0 ? width : .greatestFiniteMagnitude,
            height: .greatestFiniteMagnitude,
        ))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = numberOfLines
        container.lineBreakMode = lineBreakMode
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container)
        // The width alone: centered or trailing text starts partway in.
        return CGSize(width: ceil(used.width), height: ceil(used.maxY))
    }

}
