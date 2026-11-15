import PinLayout
public import UIKit

/// Show with `update(with:)` and end with `.hidden`, or let `show(_:for:)` do both.
@MainActor
public final class ToastView: UIView {

    // MARK: Static Properties

    private static let height: CGFloat = 62
    private static let insets = NSDirectionalEdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 24)
    private static let minWidth: CGFloat = 191
    private static let minLabelWidth: CGFloat = 109
    private static let iconSide: CGFloat = 34
    /// The stack: each toast behind the front one 14 pt lower and 5% smaller, three at most.
    private static let stackGap: CGFloat = 14
    private static let stackScaleStep: CGFloat = 0.05
    private static let stackDepth = 3
    private static let stackAnimationDuration: TimeInterval = 0.4
    private static let glass = UIGlassEffect(style: .regular)

    private static var animationDuration: TimeInterval {
        CATransaction.animationDuration()
    }

    // MARK: Computed Properties

    private var hiddenTop: CGFloat {
        -max(Self.height, glassView.frame.height) - 8
    }

    private var fades: Bool {
        UIAccessibility.isReduceMotionEnabled
    }

    // MARK: Properties

    /// The capsule's own size; the toasts behind take the front one's.
    private(set) var capsuleSize = CGSize.zero
    /// What it says while shown, so the same failure twice in a row shows once.
    private(set) var shownText: String?

    private let glassView = UIVisualEffectView(effect: ToastView.glass)
    private let labelsContainer = UIView()
    private let titleLabel = Label()
    private let subtitleLabel = Label()
    private let iconImageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)
    private let actionButton = UIButton(configuration: .plain())
    private var action: (@MainActor () -> Void)?
    /// Held for an animation's length so a burst lands as its last event.
    private var pendingEvent: Task<Void, Never>?
    private var isOnScreen = false
    /// 0 in front; set by ToastWindow.
    private var depth = 0
    private var frontSize: CGSize?
    /// The last event applied; the same one again is dropped.
    private var lastEvent: ToastViewEvent?

    // MARK: Lifecycle

    public init() {
        let window = ToastWindow.shared
        super.init(frame: window.bounds)
        setupViews()
        window.addSubview(self)
        glassView.pin
            .topCenter(-Self.height)
            .minWidth(Self.minWidth)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override public func layoutSubviews() {
        super.layoutSubviews()

        let actionWidth = action == nil ? 0 : actionButton.sizeThatFits(.zero).width + 8
        let maxLabelWidth = bounds.width - 32 - Self.insets.leading - Self.iconSide - 8 - Self.insets.trailing - actionWidth
        iconImageView.pin
            .centerStart()
            .size(Self.iconSide)
        spinner.pin
            .centerStart()
            .size(Self.iconSide)
        titleLabel.pin
            .topCenter()
            .width(maxLabelWidth)
            .minWidth(Self.minLabelWidth)
            .sizeToFit(.widthFlexible)
        subtitleLabel.pin
            .below(of: titleLabel, aligned: .center)
            .width(maxLabelWidth)
            .minWidth(Self.minLabelWidth)
            .sizeToFit(.widthFlexible)
        labelsContainer.pin
            .wrapContent()
            .after(of: iconImageView, aligned: .center)
            .marginStart(8)
        if action != nil {
            actionButton.pin
                .after(of: labelsContainer, aligned: .center)
                .marginStart(8)
                .sizeToFit()
        } else {
            // `wrapContent` wraps hidden subviews too: anywhere but on the icon, the button would stretch the capsule.
            actionButton.pin
                .center(to: iconImageView.anchor.center)
                .size(0)
        }
        glassView.contentView.pin
            .wrapContent(padding: physicalInsets(Self.insets))
        let content = glassView.contentView.bounds.size
        capsuleSize = CGSize(width: max(content.width, Self.minWidth), height: content.height)
        let size = depth == 0 ? capsuleSize : frontSize ?? capsuleSize
        let top = isOnScreen || fades ? pin.safeArea.top + CGFloat(depth) * Self.stackGap : hiddenTop
        glassView.pin
            .top(top)
            .hCenter()
            .size(size)
        // Glass doesn't draw at partial alpha, so it fades by its effect.
        if fades, isOnScreen != (glassView.effect != nil) {
            glassView.effect = isOnScreen ? Self.glass : nil
            glassView.contentView.alpha = isOnScreen && depth == 0 ? 1 : 0
        }
    }

    override public func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        glassView.frame.contains(point)
    }

    /// Only the action button takes a touch, and only on the toast in front.
    override public func hitTest(_ point: CGPoint, with _: UIEvent?) -> UIView? {
        guard action != nil, depth == 0, !actionButton.isHidden else {
            return nil
        }
        let target = actionButton.bounds.insetBy(dx: -8, dy: -8)
        return target.contains(convert(point, to: actionButton)) ? actionButton : nil
    }

    // MARK: Static Functions

    public static func hideAllCompletedToasts() {
        ToastWindow.shared.hideAllCompletedToasts()
    }

    public static func showFailure(_ title: String, subtitle: String? = nil) {
        Task { await ToastView().show(.icon(predefinedIcon: .failure, title: title, subtitle: subtitle)) }
    }

    /// A toast with one button, such as Undo; tapping it hides the toast and runs `action`.
    public static func show(_ event: ToastViewEvent,
                            actionTitle: String,
                            for duration: Duration = .seconds(5),
                            action: @escaping @MainActor () -> Void) {
        let toast = ToastView()
        toast.action = action
        toast.isUserInteractionEnabled = true
        toast.actionButton.configuration?.title = actionTitle
        toast.actionButton.isHidden = false
        // Reaching the button takes VoiceOver longer.
        let shown = UIAccessibility.isVoiceOverRunning ? duration * 2 : duration
        Task { await toast.show(event, for: shown) }
    }

    private static func text(_ title: String, _ subtitle: String?) -> String {
        [title, subtitle].compactMap(\.self).joined(separator: "\n")
    }

    // MARK: Functions

    public func update(with newEvent: ToastViewEvent) {
        pendingEvent?.cancel()
        pendingEvent = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.animationDuration))
            guard !Task.isCancelled else {
                return
            }
            self?.apply(newEvent)
        }
    }

    public func show(_ event: ToastViewEvent, for duration: Duration = .seconds(3)) async {
        update(with: event)
        try? await Task.sleep(for: duration)
        update(with: .hidden)
    }

    func place(depth: Int, frontSize: CGSize?) {
        self.depth = depth
        self.frontSize = frontSize
        let scale = 1 - CGFloat(depth) * Self.stackScaleStep
        let stackTransform = CGAffineTransform(scaleX: scale, y: scale)
        let fades = fades
        if fades {
            glassView.transform = stackTransform
        }
        UIView.animate(
            withDuration: Self.stackAnimationDuration,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: .beginFromCurrentState,
        ) {
            self.isOnScreen = true
            if !fades {
                self.glassView.transform = stackTransform
            }
            self.glassView.contentView.alpha = depth == 0 ? 1 : 0
            self.alpha = depth < Self.stackDepth ? 1 : 0
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
    }

    private func setupViews() {
        isUserInteractionEnabled = false
        isHidden = true
        glassView.cornerConfiguration = .capsule()
        glassView.clipsToBounds = true
        iconImageView.contentMode = .scaleAspectFit
        // VoiceOver announces the title; the icon and spinner are decoration.
        iconImageView.isAccessibilityElement = false
        spinner.isAccessibilityElement = false
        spinner.hidesWhenStopped = true
        spinner.stopAnimating()
        for label in [titleLabel, subtitleLabel] {
            label.textAlignment = .center
            label.numberOfLines = 2
            label.adjustsFontForContentSizeCategory = true
        }
        titleLabel.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        subtitleLabel.font = .preferredFont(forTextStyle: .footnote)
        subtitleLabel.textColor = .secondaryLabel
        actionButton.configuration?.baseForegroundColor = .tintColor
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        actionButton.isHidden = true
        actionButton.addAction(UIAction { [weak self] _ in self?.performAction() }, for: .primaryActionTriggered)
        addSubview(glassView)
        glassView.contentView.addSubview(actionButton)
        glassView.contentView.addSubview(iconImageView)
        glassView.contentView.addSubview(spinner)
        glassView.contentView.addSubview(labelsContainer)
        labelsContainer.addSubview(titleLabel)
        labelsContainer.addSubview(subtitleLabel)
    }

    private func performAction() {
        guard let action else {
            return
        }
        self.action = nil
        update(with: .hidden)
        action()
    }

    private func apply(_ event: ToastViewEvent) {
        guard event != lastEvent else {
            return
        }
        let previous = lastEvent ?? .hidden
        lastEvent = event
        transition(from: previous, with: event)
    }

    private func transition(from previous: ToastViewEvent, with event: ToastViewEvent) {
        switch event {
        case .icon(_, let title, let subtitle), .loading(let title, let subtitle): shownText = Self.text(title, subtitle)
        case .hidden: break
        }
        switch (previous, event) {
        case (.hidden, .icon(_, let title, let subtitle)) where action == nil && ToastWindow.shared.isShowing(Self.text(
            title,
            subtitle,
        )):
            removeFromSuperview()

        case (.hidden, .icon(let icon, let title, let subtitle)):
            show {
                self.updateImageView(with: icon)
                self.update(title: title)
                self.update(subtitle: subtitle)
                self.updateLayout(animated: false)
            }
            if action != nil {
                // The button is in a window of its own, out of VoiceOver's way unless focus goes there.
                actionButton.accessibilityValue = title
                UIAccessibility.post(notification: .layoutChanged, argument: actionButton)
            }

        case (.hidden, .loading(let title, let subtitle)):
            show {
                self.update(title: title)
                self.update(subtitle: subtitle)
                self.updateSpinner(isLoading: true)
                self.updateLayout(animated: false)
            }

        case (.hidden, .hidden):
            // Ended before it ever showed.
            removeFromSuperview()

        case (.icon, .icon(let icon, let title, let subtitle)):
            updateImageView(with: icon)
            update(title: title)
            update(subtitle: subtitle)
            updateLayout(animated: true)

        case (.icon, .loading(let title, let subtitle)):
            updateImageView(with: nil)
            update(title: title)
            update(subtitle: subtitle)
            updateSpinner(isLoading: true)
            updateLayout(animated: true)

        case (.icon, .hidden):
            hide {
                self.updateImageView(with: nil)
                self.update(title: nil)
                self.update(subtitle: nil)
            }

        case (.loading, .icon(let icon, let title, let subtitle)):
            updateImageView(with: icon)
            update(title: title)
            update(subtitle: subtitle)
            updateSpinner(isLoading: false)
            updateLayout(animated: true)

        case (.loading, .loading(let title, let subtitle)):
            update(title: title)
            update(subtitle: subtitle)
            updateLayout(animated: true)

        case (.loading, .hidden):
            hide {
                self.update(title: nil)
                self.update(subtitle: nil)
                self.updateSpinner(isLoading: false)
            }
        }
    }

    private func show(performBeforeAnimation: () -> Void) {
        guard window == ToastWindow.shared else {
            ToastWindow.shared.updateVisibility()
            return
        }
        isHidden = false
        performBeforeAnimation()
        layoutIfNeeded()
        ToastWindow.shared.push(self)
    }

    private func hide(performAfterAnimation: @escaping () -> Void) {
        let wasInFront = depth == 0
        ToastWindow.shared.remove(self)
        shownText = nil
        UIView.animate(withDuration: Self.animationDuration) {
            if wasInFront {
                self.isOnScreen = false
                self.setNeedsLayout()
                self.layoutIfNeeded()
            } else {
                self.alpha = 0
            }
        } completion: { _ in
            self.isOnScreen = false
            self.depth = 0
            self.glassView.transform = .identity
            self.glassView.contentView.alpha = 1
            self.isHidden = true
            self.removeFromSuperview()
            ToastWindow.shared.updateVisibility()
            performAfterAnimation()
        }
    }

    private func updateImageView(with icon: UIImage?) {
        UIView.transition(with: iconImageView, duration: Self.animationDuration, options: .transitionCrossDissolve) {
            self.iconImageView.image = icon
        }
    }

    private func update(title: String?) {
        UIView.transition(with: titleLabel, duration: Self.animationDuration, options: .transitionCrossDissolve) {
            self.titleLabel.text = title
        }
        if let title {
            UIAccessibility.post(notification: .announcement, argument: title)
        }
    }

    private func update(subtitle: String?) {
        UIView.transition(with: subtitleLabel, duration: Self.animationDuration, options: .transitionCrossDissolve) {
            self.subtitleLabel.text = subtitle
        }
    }

    private func updateSpinner(isLoading: Bool) {
        UIView.transition(with: spinner, duration: Self.animationDuration, options: .transitionCrossDissolve) {
            if isLoading {
                self.spinner.startAnimating()
            } else {
                self.spinner.stopAnimating()
            }
        }
    }

    private func updateLayout(animated: Bool) {
        let animator = UIViewPropertyAnimator(duration: animated ? Self.animationDuration : 0, curve: .easeInOut) {
            self.setNeedsLayout()
            self.layoutIfNeeded()
        }
        animator.startAnimation()
        if depth == 0 {
            ToastWindow.shared.restack()
        }
    }
}
