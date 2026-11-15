import ComponentKit
import PeopleKit
import PinLayout
import UIKit

// MARK: - ProfileHeaderView

final class ProfileHeaderView: UIView {

    // MARK: Types

    private typealias StatStrings = ProfileKitStrings.Profile.Stats

    // MARK: Static Properties

    private static let avatarSide: CGFloat = 80

    // MARK: Properties

    var onOpenURL: ((URL) -> Void)? {
        didSet { chips.onOpen = onOpenURL }
    }

    var showsHandles = true {
        didSet { setNeedsLayout() }
    }

    var tileColor = UIColor.secondarySystemBackground {
        didSet { for stat in stats { stat.backgroundColor = tileColor } }
    }

    private let avatar = AvatarView()
    private let nameLabel = Label()
    private let usernameLabel = CopyableLabel(copyActionName: ProfileKitStrings.ProfileHeader.A11y.copyUsername)
    private let badgeLabel = BadgeLabel()
    private let bioLabel = Label()
    private let stats = (0..<3).map { _ in StatTile() }
    private let chips = HandleChipsView()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        nameLabel.font = .preferredFont(forTextStyle: .title2, weight: .bold)
        nameLabel.accessibilityTraits = .header
        usernameLabel.font = .preferredFont(forTextStyle: .subheadline)
        badgeLabel.font = .preferredFont(forTextStyle: .footnote, weight: .semibold)
        badgeLabel.textColor = .systemOrange
        badgeLabel.backgroundColor = .systemOrange.withAlphaComponent(0.14)
        badgeLabel.textAlignment = .center
        badgeLabel.clipsToBounds = true
        badgeLabel.adjustsFontForContentSizeCategory = true
        bioLabel.font = .preferredFont(forTextStyle: .subheadline)
        for label in [nameLabel, usernameLabel, bioLabel] {
            label.numberOfLines = 0
            label.adjustsFontForContentSizeCategory = true
        }
        for tile in stats {
            tile.backgroundColor = tileColor
        }
        for view in [avatar, nameLabel, usernameLabel, badgeLabel, bioLabel, chips] + stats {
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    func show(_ profile: PublicProfile) {
        setPlaceholderStyle(false)
        avatar.show(name: profile.name, avatar: profile.avatar)
        nameLabel.text = profile.name
        usernameLabel.text = profile.username.map { "@\($0)" }
        usernameLabel.isHidden = profile.username == nil
        badgeLabel.text = profile.roleBadge
        badgeLabel.isHidden = profile.roleBadge == nil
        bioLabel.text = profile.bio
        bioLabel.isHidden = profile.bio.isEmpty
        let counts = profile.stats
        let values = [
            (counts.submitted, StatStrings.submitted, StatStrings.A11y.submitted(counts.submitted)),
            (counts.approved, StatStrings.approved, StatStrings.A11y.approved(counts.approved)),
            (counts.cities, StatStrings.Cities.caption(counts.cities), StatStrings.A11y.cities(counts.cities)),
        ]
        for (tile, (value, caption, spoken)) in zip(stats, values) {
            tile.show(value: value.formatted(), caption: caption, spoken: spoken, isPlaceholder: false)
        }
        chips.show(profile.handles)
        setNeedsLayout()
    }

    func showPlaceholder(name: String?, badge: String?) {
        setPlaceholderStyle(true)
        nameLabel.textColor = name == nil ? .tertiaryLabel : .label
        avatar.show(name: name ?? "", avatar: nil)
        nameLabel.text = name ?? "—"
        usernameLabel.text = "—"
        usernameLabel.isHidden = false
        badgeLabel.text = badge
        badgeLabel.isHidden = badge == nil
        bioLabel.text = nil
        bioLabel.isHidden = true
        for (tile, caption) in zip(stats, [StatStrings.submitted, StatStrings.approved, StatStrings.Cities.placeholder]) {
            tile.show(value: "–", caption: caption, spoken: StatStrings.A11y.notLoaded(caption), isPlaceholder: true)
        }
        chips.show(Handles())
        setNeedsLayout()
    }

    private func setPlaceholderStyle(_ placeholder: Bool) {
        nameLabel.textColor = .label
        usernameLabel.textColor = placeholder ? .tertiaryLabel : .secondaryLabel
        usernameLabel.isCopyable = !placeholder
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        let isLargeText = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        avatar.pin
            .top(8)
            .start()
            .size(Self.avatarSide)
        let columnStart = isLargeText ? 0 : Self.avatarSide + 16
        let columnTop = isLargeText ? avatar.frame.maxY + 12 : avatar.frame.minY
        var bottom = layoutColumn(top: columnTop, start: columnStart, width: width - columnStart)
        if !isLargeText {
            let offset = max(0, (Self.avatarSide - (bottom - columnTop)) / 2)
            for view in [nameLabel, usernameLabel, badgeLabel, bioLabel] {
                view.frame.origin.y += offset
            }
            bottom = max(bottom + offset, avatar.frame.maxY)
        }
        bottom = layoutStats(top: bottom + 16, width: width, stacked: isLargeText)

        chips.isHidden = !showsHandles || chips.subviews.isEmpty
        if !chips.isHidden {
            chips.pin
                .top(bottom + 16)
                .start()
                .width(width)
                .sizeToFit(.width)
            bottom = chips.frame.maxY
        }
        return bottom
    }

    private func layoutColumn(top: CGFloat, start: CGFloat, width: CGFloat) -> CGFloat {
        nameLabel.pin
            .top(top)
            .start(start)
            .width(width)
            .sizeToFit(.width)
        var bottom = nameLabel.frame.maxY
        if !usernameLabel.isHidden {
            usernameLabel.pin
                .top(bottom + 2)
                .start(start)
                .width(width)
                .sizeToFit(.width)
            bottom = usernameLabel.frame.maxY
        }
        if !badgeLabel.isHidden {
            let size = badgeLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
            let usernameWidth = usernameLabel.intrinsicContentSize.width
            if !usernameLabel.isHidden, usernameWidth + 8 + size.width <= width {
                badgeLabel.pin
                    .vCenter(to: usernameLabel.edge.vCenter)
                    .start(start + usernameWidth + 8)
                    .size(size)
                bottom = max(bottom, badgeLabel.frame.maxY)
            } else {
                badgeLabel.pin
                    .top(bottom + 6)
                    .start(start)
                    .size(size)
                bottom = badgeLabel.frame.maxY
            }
        }
        if !bioLabel.isHidden {
            bioLabel.pin
                .top(bottom + 8)
                .start(start)
                .width(width)
                .sizeToFit(.width)
            bottom = bioLabel.frame.maxY
        }
        return bottom
    }

    private func layoutStats(top: CGFloat, width: CGFloat, stacked: Bool) -> CGFloat {
        let spacing: CGFloat = 8
        guard !stacked else {
            var bottom = top - spacing
            for tile in stats {
                tile.pin
                    .top(bottom + spacing)
                    .start()
                    .width(width)
                    .sizeToFit(.width)
                bottom = tile.frame.maxY
            }
            return bottom
        }
        let tileWidth = (width - spacing * CGFloat(stats.count - 1)) / CGFloat(stats.count)
        let height = stats.map { $0.sizeThatFits(CGSize(width: tileWidth, height: .greatestFiniteMagnitude)).height }.max() ?? 0
        for (index, tile) in stats.enumerated() {
            tile.pin
                .top(top)
                .start(CGFloat(index) * (tileWidth + spacing))
                .width(tileWidth)
                .height(height)
        }
        return top + height
    }
}

// MARK: - StatTile

private final class StatTile: UIView {

    // MARK: Static Properties

    private static let padding = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)

    // MARK: Properties

    private let valueLabel = Label()
    private let captionLabel = Label()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        // Title 2's default size, in SF Pro Rounded.
        let bold = UIFont.systemFont(ofSize: 22, weight: .bold)
        let rounded = bold.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 22) } ?? bold
        valueLabel.font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: rounded)
        captionLabel.font = .preferredFont(forTextStyle: .footnote)
        captionLabel.textColor = .secondaryLabel
        captionLabel.numberOfLines = 0
        for label in [valueLabel, captionLabel] {
            label.adjustsFontForContentSizeCategory = true
            addSubview(label)
        }
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    func show(value: String, caption: String, spoken: String, isPlaceholder: Bool) {
        valueLabel.text = value
        valueLabel.textColor = isPlaceholder ? .tertiaryLabel : .label
        captionLabel.text = caption
        accessibilityLabel = spoken
        setNeedsLayout()
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        let padding = Self.padding
        let contentWidth = width - padding.left - padding.right
        valueLabel.pin
            .top(padding.top)
            .start(padding)
            .width(contentWidth)
            .sizeToFit(.width)
        captionLabel.pin
            .below(of: valueLabel)
            .start(padding)
            .width(contentWidth)
            .marginTop(2)
            .sizeToFit(.width)
        return captionLabel.frame.maxY + padding.bottom
    }
}
