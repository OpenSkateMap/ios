import AppLinkKit
import ComponentKit
import PinLayout
import UIKit

// MARK: - LegalFooterView

final class LegalFooterView: UICollectionReusableView {

    // MARK: Static Properties

    static let elementKind = "legal-footer"

    private static let version: String = {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String
        return build.map { ProfileKitStrings.LegalFooter.versionBuild(version, $0) }
            ?? ProfileKitStrings.LegalFooter.version(version)
    }()

    // MARK: Properties

    var onOpenURL: ((URL) -> Void)?

    private let textView = UITextView().softEdges()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        textView.pin
            .top(8)
            .horizontally(16)
            .sizeToFit(.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let text = textView.sizeThatFits(CGSize(width: size.width - 32, height: .greatestFiniteMagnitude))
        return CGSize(width: size.width, height: ceil(text.height) + 8 + 24)
    }

    override func preferredLayoutAttributesFitting(_ layoutAttributes: UICollectionViewLayoutAttributes)
        -> UICollectionViewLayoutAttributes {
        let attributes = layoutAttributes
        attributes.size.height = sizeThatFits(CGSize(width: layoutAttributes.size.width, height: .greatestFiniteMagnitude))
            .height
        return attributes
    }

    // MARK: Static Functions

    private static func text() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineSpacing = 4
        let base: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .footnote),
            .foregroundColor: UIColor.secondaryLabel,
            .paragraphStyle: paragraph,
        ]
        let text = NSMutableAttributedString()
        for (index, page) in LegalPage.allCases.enumerated() {
            if index > 0 {
                text.append(NSAttributedString(string: " · ", attributes: base))
            }
            text.append(NSAttributedString(string: page.title, attributes: base.merging([.link: page.url]) { $1 }))
        }
        text.append(NSAttributedString(string: "\n\(version)", attributes: base))
        return text
    }

    // MARK: Functions

    private func setupViews() {
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.linkTextAttributes = [
            .foregroundColor: UIColor.secondaryLabel,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        textView.attributedText = Self.text()
        textView.delegate = self
        addSubview(textView)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            self.textView.attributedText = Self.text()
            self.setNeedsLayout()
        }
    }
}

// MARK: UITextViewDelegate

extension LegalFooterView: UITextViewDelegate {
    func textView(_: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard case .link(let url) = textItem.content else {
            return defaultAction
        }
        return UIAction { [weak self] _ in self?.onOpenURL?(url) }
    }
}
