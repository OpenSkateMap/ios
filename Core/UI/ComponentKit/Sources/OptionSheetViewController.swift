import PinLayout
public import UIKit

public final class OptionSheetViewController: UIViewController {

    // MARK: Static Properties

    private static let inset: CGFloat = 20
    private static let closeTop: CGFloat = 24
    private static let closeSide: CGFloat = 44
    /// A solid gray that stands apart from the form's cards behind it (in dark mode they're gray 5 too).
    private static let barFill = UIColor { $0.userInterfaceStyle == .dark ? .systemGray4 : .systemGray5 }

    // MARK: Computed Properties

    /// A custom detent is a height within the sheet's safe area; the system adds the home indicator.
    private var sideMargins: UIEdgeInsets {
        UIEdgeInsets(
            top: 0,
            left: view.safeAreaInsets.left + Self.inset,
            bottom: 0,
            right: view.safeAreaInsets.right + Self.inset,
        )
    }

    private var preferredHeight: CGFloat {
        let width = view.bounds.width > 0 ? view.bounds.width : 393
        let keyboardHeight = view.window.map { $0.bounds.intersection(keyboardFrame).height } ?? 0
        let content = layoutScrollingContent(width: width) + buttonsHeight(width: width - sideMargins.left - sideMargins.right)
        guard keyboardHeight == 0, isFloating else {
            return content + 16 + max(keyboardHeight - view.safeAreaInsets.bottom, 0)
        }
        return content + Self.inset - view.safeAreaInsets.bottom
    }

    /// iOS 26 floats a sheet below full height: there Confirm nests in its corners (HIG); else it clears the home indicator.
    private var confirmBottom: CGFloat {
        let keyboard = view.convert(keyboardFrame, from: nil)
        let covered = view.bounds.intersection(keyboard).height
        if covered == 0, isFloating {
            return Self.inset
        }
        return max(covered, view.safeAreaInsets.bottom) + 16
    }

    private var isFloating: Bool {
        guard let window = view.window else {
            return false
        }
        return view.convert(view.bounds, to: window).maxY < window.bounds.maxY - 1
    }

    // MARK: Properties

    /// A second capsule on Confirm's leading side, such as Previous in a sheet that goes step by step; none when nil.
    public var secondaryAction: UIAction? {
        didSet {
            secondaryButton.isHidden = secondaryAction == nil
            secondaryButton.configuration?.title = secondaryAction?.title
            viewIfLoaded?.setNeedsLayout()
        }
    }

    public var isSecondaryEnabled = true {
        didSet {
            secondaryButton.isEnabled = isSecondaryEnabled
        }
    }

    /// False when Confirm moves the sheet on, at once and without its busy state, instead of closing it; its owner
    /// closes it.
    public var closesOnConfirm = true

    /// Runs once the sheet has closed, whether Confirm closed it or the person did.
    public var onClose: (() -> Void)?

    public var isConfirmEnabled = true {
        didSet {
            confirmButton.isEnabled = isConfirmEnabled && !isConfirming
        }
    }

    private var isConfirming = false {
        didSet {
            confirmButton.configuration?.showsActivityIndicator = isConfirming
            confirmButton.isEnabled = isConfirmEnabled && !isConfirming
        }
    }

    private var keyboardFrame = CGRect.zero
    /// UIKit resolves the detent before the sheet has a width, so a layout at another height resolves it again.
    private var resolvedHeight: CGFloat?
    private let content: UIView
    private let failureTitle: String
    private let onConfirm: () async throws -> Void
    private var confirming: Task<Void, Never>?
    private let background = TintedBackgroundView()
    private let scrollView = UIScrollView().softEdges()
    private let closeButton = UIButton(configuration: .glass())
    private let titleLabel = Label()
    private let messageLabel = Label()
    private let confirmBar = UIView()
    private let confirmButton: UIButton
    private let secondaryButton = UIButton(configuration: .secondaryCapsule(title: ""))

    // MARK: Lifecycle

    public init(title: String,
                message: String?,
                content: UIView,
                tint: UIColor?,
                confirmTitle: String = ComponentKitStrings.OptionSheet.confirm,
                failureTitle: String = ComponentKitStrings.OptionSheet.Failure.title,
                onConfirm: @escaping () async throws -> Void) {
        self.content = content
        self.failureTitle = failureTitle
        self.onConfirm = onConfirm
        confirmButton = UIButton(configuration: .primaryCapsule(title: confirmTitle))
        super.init(nibName: nil, bundle: nil)
        background.tint = tint
        titleLabel.text = title
        messageLabel.text = message
        messageLabel.isHidden = message == nil
        sheetPresentationController?.prefersGrabberVisible = true
        sheetPresentationController?.detents = [.custom(identifier: .init("content")) { [weak self] context in
            guard let self else {
                return context.maximumDetentValue
            }
            let height = preferredHeight
            resolvedHeight = height
            return min(height, context.maximumDetentValue)
        }]
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupActions()
        setupObservers()
    }

    override public func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        resolveDetentIfStale(animated: false)
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if isBeingDismissed || presentingViewController == nil {
            onClose?()
            onClose = nil
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        background.pin
            .all()
        let sides = sideMargins
        closeButton.pin
            .top(Self.closeTop)
            .end(sides)
            .size(Self.closeSide)
        let buttonsWidth = view.bounds.width - sides.left - sides.right
        let buttonsHeight = buttonsHeight(width: buttonsWidth)
        confirmBar.pin
            .bottom()
            .horizontally()
            .height(confirmBottom + buttonsHeight)
        if secondaryButton.isHidden {
            confirmButton.pin
                .top()
                .horizontally(sides)
                .height(buttonsHeight)
        } else {
            let half = (buttonsWidth - 10) / 2
            secondaryButton.pin
                .top()
                .start(sides)
                .width(half)
                .height(buttonsHeight)
            confirmButton.pin
                .top()
                .end(sides)
                .width(half)
                .height(buttonsHeight)
        }
        scrollView.pin
            .all()
        let contentHeight = layoutScrollingContent(width: view.bounds.width)
        scrollView.contentSize = CGSize(width: view.bounds.width, height: contentHeight)
        scrollView.contentInset.bottom = confirmBar.frame.height
        scrollView.verticalScrollIndicatorInsets.bottom = confirmBar.frame.height
        resolveDetentIfStale(animated: view.window != nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        confirming?.cancel()
    }

    // MARK: Overrides

    override public func accessibilityPerformEscape() -> Bool {
        dismiss(animated: true)
        return true
    }

    // MARK: Static Functions

    private static func firstResponder(in view: UIView) -> UIView? {
        view.isFirstResponder ? view : view.subviews.lazy.compactMap { firstResponder(in: $0) }.first
    }

    // MARK: Functions

    public func setTitle(_ title: String) {
        titleLabel.text = title
        view.setNeedsLayout()
    }

    public func setConfirmTitle(_ title: String) {
        confirmButton.configuration?.title = title
    }

    public func contentDidChange() {
        view.setNeedsLayout()
        sheetPresentationController?.animateChanges {
            sheetPresentationController?.invalidateDetents()
        }
    }

    private func buttonsHeight(width: CGFloat) -> CGFloat {
        guard !secondaryButton.isHidden else {
            return confirmButton.capsuleHeight(fitting: width)
        }
        let half = (width - 10) / 2
        return max(confirmButton.capsuleHeight(fitting: half), secondaryButton.capsuleHeight(fitting: half))
    }

    private func resolveDetentIfStale(animated: Bool) {
        guard view.bounds.width > 0, let resolvedHeight, abs(preferredHeight - resolvedHeight) >= 0.5,
              let sheet = sheetPresentationController else {
            return
        }
        if animated {
            sheet.animateChanges { sheet.invalidateDetents() }
        } else {
            sheet.invalidateDetents()
        }
    }

    private func setupViews() {
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = false
        titleLabel.font = .preferredFont(forTextStyle: .title1, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header
        messageLabel.font = .preferredFont(forTextStyle: .body)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.numberOfLines = 0
        closeButton.configuration?.image = UIImage(systemName: "xmark")
        closeButton.configuration?.cornerStyle = .capsule
        closeButton.accessibilityLabel = ComponentKitStrings.OptionSheet.close
        let edgeEffect = UIScrollEdgeElementContainerInteraction()
        edgeEffect.scrollView = scrollView
        edgeEffect.edge = .bottom
        confirmBar.addInteraction(edgeEffect)
        // Content scrolls under the bar, so its capsules are solid in every state; UIKit's disabled look is see-through.
        secondaryButton.configuration?.baseBackgroundColor = Self.barFill
        for button in [confirmButton, secondaryButton] {
            button.configuration?.background.backgroundColorTransformer = UIConfigurationColorTransformer { [weak button] color in
                button?.isEnabled == false ? Self.barFill : color
            }
        }
        secondaryButton.isHidden = secondaryAction == nil
        confirmBar.addSubview(secondaryButton)
        confirmBar.addSubview(confirmButton)
        for subview in [titleLabel, messageLabel, content] {
            scrollView.addSubview(subview)
        }
        for subview in [background, scrollView, closeButton, confirmBar] {
            view.addSubview(subview)
        }
    }

    private func setupActions() {
        closeButton.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .primaryActionTriggered)
        confirmButton.addAction(UIAction { [weak self] _ in self?.confirm() }, for: .primaryActionTriggered)
        secondaryButton.addAction(UIAction { [weak self] _ in
            if let self, let action = secondaryAction {
                action.performWithSender(secondaryButton, target: nil)
            }
        }, for: .primaryActionTriggered)
    }

    private func setupObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidChangeFrame),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil,
        )
    }

    @discardableResult
    private func layoutScrollingContent(width: CGFloat) -> CGFloat {
        let sides = sideMargins
        let innerWidth = width - sides.left - sides.right
        let titleTop = Self.closeTop + Self.closeSide / 2 - titleLabel.font.lineHeight / 2
        let titleWidth = innerWidth - Self.closeSide - 12
        titleLabel.pin
            .top(titleTop)
            .start(sides)
            .width(titleWidth)
            .sizeToFit(.width)
        var bottom = titleLabel.frame.maxY
        if !messageLabel.isHidden {
            messageLabel.pin
                .below(of: titleLabel)
                .start(sides)
                .width(innerWidth)
                .marginTop(6)
                .sizeToFit(.width)
            bottom = messageLabel.frame.maxY
        }
        let contentHeight = content.sizeThatFits(CGSize(width: innerWidth, height: .greatestFiniteMagnitude)).height
        content.pin
            .top(bottom + 20)
            .start(sides)
            .width(innerWidth)
            .height(contentHeight)
        return content.frame.maxY + 24
    }

    @objc
    private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let window = view.window,
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let keyboard = window.convert(frame, from: window.screen.coordinateSpace)
        guard keyboard != keyboardFrame else {
            return
        }
        keyboardFrame = keyboard
        contentDidChange()
    }

    /// UIKit scrolls a focused field only just into view, which left what follows it (a credit's permission switch) under
    /// Confirm; once the keyboard and the sheet settle, the field goes to the top and as much after it as fits shows.
    @objc
    private func keyboardDidChangeFrame() {
        guard view.bounds.intersection(view.convert(keyboardFrame, from: nil)).height > 0,
              let field = Self.firstResponder(in: content) else {
            return
        }
        let fieldTop = field.convert(field.bounds, to: scrollView).minY - (Self.closeTop + Self.closeSide + 12)
        let end = scrollView.contentSize.height + scrollView.contentInset.bottom - scrollView.bounds.height
        let target = min(fieldTop, end)
        if target > scrollView.contentOffset.y {
            scrollView.setContentOffset(CGPoint(x: 0, y: target), animated: true)
        }
    }

    private func confirm() {
        guard isConfirmEnabled, confirming == nil else {
            return
        }
        guard closesOnConfirm else {
            confirming = Task { [weak self, onConfirm] in
                try? await onConfirm()
                self?.confirming = nil
            }
            return
        }
        isConfirming = true
        confirming = Task { [weak self, onConfirm, failureTitle] in
            do {
                try await onConfirm()
                self?.dismiss(animated: true)
            } catch is CancellationError {
                // Cancelled by the person: the sheet stays as it was.
            } catch {
                ToastView.showFailure(failureTitle, subtitle: ComponentKitStrings.OptionSheet.Failure.message)
            }
            self?.confirming = nil
            self?.isConfirming = false
        }
    }
}
