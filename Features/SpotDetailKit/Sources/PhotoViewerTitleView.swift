import ComponentKit
import PinLayout
import UIKit

/// Who took the photo on screen and the day it was added, in one glass capsule.
final class PhotoViewerTitleView: UIVisualEffectView {

    // MARK: Static Properties

    private static let minimumHeight: CGFloat = 44
    private static let minimumTextWidth: CGFloat = 150
    private static let insets = UIEdgeInsets(top: 4, left: 14, bottom: 4, right: 14)
    private static let lineSpacing: CGFloat = 2
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    // MARK: Properties

    private let nameLabel = Label()
    private let dateLabel = Label()

    // MARK: Lifecycle

    init() {
        super.init(effect: UIGlassEffect())

        cornerConfiguration = .capsule()
        isUserInteractionEnabled = false
        nameLabel.font = .preferredFont(forTextStyle: .headline)
        dateLabel.font = .preferredFont(forTextStyle: .caption1)
        dateLabel.textColor = .secondaryLabel
        for label in [nameLabel, dateLabel] {
            label.adjustsFontForContentSizeCategory = true
            label.textAlignment = .center
            label.lineBreakMode = .byTruncatingTail
            label.linesAtAccessibilitySizes = 0
            label.isAccessibilityElement = false
            contentView.addSubview(label)
        }
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        let width = bounds.width - Self.insets.left - Self.insets.right
        let name = measure(nameLabel, width: width)
        let date = measure(dateLabel, width: width)
        let spacing = name.height > 0 && date.height > 0 ? Self.lineSpacing : 0
        let top = ((bounds.height - name.height - spacing - date.height) / 2).rounded(.down)
        nameLabel.pin
            .top(top)
            .horizontally(Self.insets)
            .height(name.height)
        dateLabel.pin
            .top(top + name.height + spacing)
            .horizontally(Self.insets)
            .height(date.height)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = max(size.width - Self.insets.left - Self.insets.right, 0)
        let name = measure(nameLabel, width: width)
        let date = measure(dateLabel, width: width)
        let spacing = name.height > 0 && date.height > 0 ? Self.lineSpacing : 0
        let text = CGSize(width: max(name.width, date.width), height: name.height + spacing + date.height)
        return CGSize(
            width: min(max(ceil(text.width), Self.minimumTextWidth) + Self.insets.left + Self.insets.right, size.width),
            height: max(ceil(text.height) + Self.insets.top + Self.insets.bottom, Self.minimumHeight),
        )
    }

    // MARK: Functions

    /// `credit` is the localized "Photo by …" VoiceOver reads; the capsule shows the name alone.
    func show(name: String?, credit: String?, addedAt: Date?) {
        let date = addedAt.map(Self.dateFormatter.string(from:))
        nameLabel.text = name
        dateLabel.text = date
        accessibilityLabel = credit ?? date
        accessibilityValue = credit == nil ? nil : date
        isHidden = name == nil && date == nil
        setNeedsLayout()
    }

    private func measure(_ label: Label, width: CGFloat) -> CGSize {
        guard label.text?.isEmpty == false else {
            return .zero
        }
        let size = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: min(size.width, width), height: size.height)
    }
}
