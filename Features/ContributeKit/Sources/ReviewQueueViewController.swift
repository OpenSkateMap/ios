import ComponentKit
import FactoryKit
import IdentifiedCollections
import ImageKit
import PinLayout
import ReviewKit
import UIKit

// MARK: - ReviewQueueViewController

final class ReviewQueueViewController: UIViewController {

    // MARK: Static Properties

    private static let decisionDistance: CGFloat = 110
    private static let decisionVelocity: CGFloat = 900
    private static let undoSeconds = 5.0

    // MARK: Computed Properties

    private var topCard: ReviewCard? {
        model.cards.first { !leavingCardIDs.contains($0.id) }
    }

    // MARK: Properties

    private let model = ReviewQueueModel()
    private let stackArea = UIView()
    private let rejectButton = UIButton(configuration: ReviewQueueViewController.rejectConfiguration())
    private let approveButton = UIButton(configuration: .primaryCapsule(title: ContributeKitStrings.ReviewQueue.approve))
    private let editItem = UIBarButtonItem(image: UIImage(systemName: "pencil"))
    private let toast = ReviewToastView()
    private lazy var videosItem = UIBarButtonItem(
        title: ContributeKitStrings.ReviewQueue.videos,
        image: UIImage(systemName: "play.rectangle.on.rectangle"),
        primaryAction: UIAction { [weak self] _ in self?.navigationController?.pushViewController(
            VideoReviewViewController(),
            animated: true,
        ) },
    )
    private var cardViews = [ReviewCard.ID: ReviewCardView]()
    private var leavingCardIDs = Set<ReviewCard.ID>()
    private var shownDecision: ReviewSession.Decision?
    private var shownNotice: ReviewSession.Notice?
    private var isPastDecision = false
    private var isOnScreen = false

    // MARK: Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)

        title = model.isCurator ? ContributeKitStrings.ReviewQueue.title : ContributeKitStrings.ReviewQueue.ownerTitle
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItems()
        setupViews()
        setupActions()
        load()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        isOnScreen = true
        for (id, cardView) in cardViews {
            cardView.isOnTop = id == topCard?.id
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        isOnScreen = false
        for cardView in cardViews.values {
            cardView.isOnTop = false
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let inset: CGFloat = 16
        let rowWidth = view.bounds.width - view.safeAreaInsets.left - view.safeAreaInsets.right - inset * 2
        let stacks = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let buttons = stacks ? [approveButton, rejectButton] : [rejectButton, approveButton]
        let frames = RowLayout.frames(
            for: buttons,
            width: rowWidth,
            spacing: 12,
            stacks: stacks,
            displayScale: traitCollection.displayScale,
        ) { button, width in
            button.capsuleHeight(fitting: width)
        }
        let top = view.bounds.height - view.safeAreaInsets.bottom - 12 - (frames.map(\.maxY).max() ?? 0)
        // swiftlint:disable pinlayout_left_right - Reject and Approve sit on the sides their swipes go
        for (button, frame) in zip(buttons, frames) {
            button.pin
                .top(top + frame.minY)
                .left(view.safeAreaInsets.left + inset + frame.minX)
                .size(frame.size)
        }
        // swiftlint:enable pinlayout_left_right
        stackArea.pin
            .top(view.pin.safeArea.top + 8)
            .above(of: approveButton)
            .horizontally(view.pin.safeArea)
            .marginHorizontal(inset)
            .marginBottom(20)
        toast.pin
            .above(of: approveButton)
            .horizontally(view.pin.safeArea)
            .marginHorizontal(24)
            .marginBottom(12)
            .sizeToFit(.width)
        for (id, cardView) in cardViews {
            layout(cardView, isTop: id == topCard?.id)
        }
    }

    override func updateProperties() {
        super.updateProperties()

        render(cards: model.cards)
        let hasTop = topCard.map { !model.isDeciding($0.id) } ?? false
        let isEmpty = model.cards.isEmpty && !model.hasDecisionsInFlight && leavingCardIDs.isEmpty
        // The last card is away and its decision isn't back yet: the stack waits on it.
        let isSettling = model.cards.isEmpty && model.hasDecisionsInFlight && leavingCardIDs.isEmpty
        for button in [rejectButton, approveButton] {
            button.isEnabled = hasTop
            button.isHidden = isEmpty
        }
        editItem.isEnabled = hasTop
        if isSettling {
            contentUnavailableConfiguration = UIContentUnavailableConfiguration.loading()
        } else {
            updateEmptyState(isEmpty: isEmpty)
        }
        videosItem.badge = model.videoCount > 0 ? .count(model.videoCount) : nil
        showDecisionIfNew(model.lastDecision)
        showNoticeIfNew(model.notice)
    }

    // MARK: Static Functions

    private static func rejectConfiguration() -> UIButton.Configuration {
        var configuration = UIButton.Configuration.glass()
        configuration.title = ContributeKitStrings.ReviewQueue.reject
        configuration.image = UIImage(systemName: "xmark")
        configuration.imagePadding = 8
        configuration.cornerStyle = .capsule
        configuration.baseForegroundColor = .label
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 24, bottom: 15, trailing: 24)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: .current)
            return attributes
        }
        return configuration
    }

    // MARK: Functions

    private func setupNavigationItems() {
        navigationItem.largeTitleDisplayMode = .never
        editItem.primaryAction = UIAction(image: UIImage(systemName: "pencil")) { [weak self] _ in self?.editTopCard() }
        editItem.accessibilityLabel = ContributeKitStrings.ReviewQueue.edit
        navigationItem.rightBarButtonItems = [editItem, videosItem]
    }

    private func setupViews() {
        view.backgroundColor = .systemBackground
        approveButton.configuration?.image = UIImage(systemName: "checkmark")
        approveButton.configuration?.imagePadding = 8
        for subview in [stackArea, rejectButton, approveButton, toast] {
            view.addSubview(subview)
        }
    }

    private func setupActions() {
        rejectButton.addAction(UIAction { [weak self] _ in self?.askRejectReason() }, for: .primaryActionTriggered)
        approveButton.addAction(UIAction { [weak self] _ in self?.approveTopCard() }, for: .primaryActionTriggered)
        toast.onUndo = { [weak self] in
            Task { [weak self] in
                await self?.model.undo()
                self?.toast.finishUndoing()
            }
        }
    }

    private func load() {
        Task { await model.load() }
    }

    private func render(cards: IdentifiedArrayOf<ReviewCard>) {
        let visible = Array(cards.filter { !leavingCardIDs.contains($0.id) }.prefix(2))
        for (id, cardView) in cardViews where !visible.contains(where: { $0.id == id }) {
            cardView.removeFromSuperview()
            cardViews[id] = nil
        }
        for (index, card) in visible.enumerated().reversed() {
            let cardView: ReviewCardView
            if let existing = cardViews[card.id] {
                cardView = existing
                if existing.card != card {
                    existing.configure(card, cityName: model.cityName(for: card.cityID))
                }
            } else {
                cardView = ReviewCardView(card: card, cityName: model.cityName(for: card.cityID))
                cardViews[card.id] = cardView
                stackArea.insertSubview(cardView, at: 0)
            }
            if index == 0 {
                stackArea.bringSubviewToFront(cardView)
                makeInteractive(cardView)
            } else {
                cardView.isUserInteractionEnabled = false
                cardView.accessibilityElementsHidden = true
            }
            cardView.isOnTop = isOnScreen && index == 0
            layout(cardView, isTop: index == 0)
        }
    }

    private func layout(_ cardView: ReviewCardView, isTop: Bool) {
        let transform = cardView.transform
        cardView.transform = .identity
        cardView.frame = stackArea.bounds
        cardView.transform = isTop ? transform : CGAffineTransform(translationX: 0, y: 12).scaledBy(x: 0.95, y: 0.95)
    }

    private func makeInteractive(_ cardView: ReviewCardView) {
        cardView.isUserInteractionEnabled = true
        cardView.accessibilityElementsHidden = false
        guard cardView.gestureRecognizers?.isEmpty ?? true else {
            return
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(swipe(_:)))
        pan.delegate = self
        cardView.addGestureRecognizer(pan)
        cardView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapCard)))
        cardView.accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: ContributeKitStrings.ReviewQueue.approve) { [weak self] _ in
                self?.approveTopCard()
                return true
            },
            UIAccessibilityCustomAction(name: ContributeKitStrings.ReviewQueue.reject) { [weak self] _ in
                self?.askRejectReason()
                return true
            },
            UIAccessibilityCustomAction(name: ContributeKitStrings.ReviewQueue.edit) { [weak self] _ in
                self?.editTopCard()
                return true
            },
        ]
    }

    private func updateEmptyState(isEmpty: Bool) {
        guard isEmpty else {
            contentUnavailableConfiguration = nil
            return
        }
        switch model.phase {
        case .idle where !model.isQueueKnown, .loading where !model.isQueueKnown:
            contentUnavailableConfiguration = UIContentUnavailableConfiguration.loading()

        case .failed(let notice) where !model.isQueueKnown:
            var configuration = UIContentUnavailableConfiguration.empty()
            configuration.image = UIImage(systemName: "wifi.exclamationmark")
            configuration.text = ContributeKitStrings.ReviewQueue.Failed.title
            configuration.secondaryText = notice.loadFailureMessage
            var button = UIButton.Configuration.filled()
            button.title = ContributeKitStrings.ReviewQueue.Failed.retry
            button.cornerStyle = .capsule
            configuration.button = button
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in self?.load() }
            contentUnavailableConfiguration = configuration

        case .idle, .loading, .failed, .loaded:
            var configuration = UIContentUnavailableConfiguration.empty()
            configuration.image = UIImage(systemName: "checkmark.seal")
            configuration.text = ContributeKitStrings.ReviewQueue.Empty.title
            configuration.secondaryText = ContributeKitStrings.ReviewQueue.Empty.message
            contentUnavailableConfiguration = configuration
        }
    }

    private func approveTopCard() {
        guard let id = topCard?.id, !model.isDeciding(id) else {
            return
        }
        UINotificationFeedbackGenerator(view: view).notificationOccurred(.success)
        flyAway(id, toRight: true) { [model] in
            Task { await model.approve(id) }
        }
    }

    private func reject(_ id: ReviewCard.ID, reason: RejectReason) {
        UIImpactFeedbackGenerator(style: .medium, view: view).impactOccurred()
        flyAway(id, toRight: false) { [model] in model.reject(id, reason: reason) }
    }

    private func askRejectReason() {
        guard let card = topCard, !model.isDeciding(card.id) else {
            return
        }
        let sheet = UIAlertController(
            title: ContributeKitStrings.ReviewQueue.RejectSheet.title(card.title),
            message: ContributeKitStrings.ReviewQueue.RejectSheet.message,
            preferredStyle: .actionSheet,
        )
        for reason in RejectReason.allCases {
            sheet.addAction(UIAlertAction(title: reason.title, style: .default) { [weak self] _ in self?.reject(
                card.id,
                reason: reason,
            ) })
        }
        sheet.addAction(UIAlertAction(title: ContributeKitStrings.Alert.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = rejectButton
        present(sheet, animated: true)
    }

    private func editTopCard() {
        guard let card = topCard, !model.isDeciding(card.id) else {
            return
        }
        present(NewSpotSheetController(reviewing: card), animated: true)
    }

    private func flyAway(_ id: ReviewCard.ID, toRight: Bool, then decide: @escaping () -> Void) {
        guard let cardView = cardViews[id] else {
            decide()
            return
        }
        leavingCardIDs.insert(id)
        cardViews[id] = nil
        let distance = (view.bounds.width + cardView.bounds.width) * (toRight ? 1 : -1)
        let fades = UIAccessibility.isReduceMotionEnabled
        UIView.animate(withDuration: 0.3, delay: 0, options: [.curveEaseIn]) {
            if fades {
                cardView.alpha = 0
            } else {
                cardView.transform = CGAffineTransform(translationX: distance, y: 40).rotated(by: toRight ? 0.3 : -0.3)
            }
            cardView.setVerdictHint(toRight ? 1 : -1)
        } completion: { [weak self] _ in
            cardView.removeFromSuperview()
            decide()
            self?.leavingCardIDs.remove(id)
            self?.setNeedsUpdateProperties()
        }
        setNeedsUpdateProperties()
    }

    private func snapBack(_ cardView: ReviewCardView) {
        let damping: CGFloat = UIAccessibility.isReduceMotionEnabled ? 1 : 0.7
        UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: 0) {
            cardView.transform = .identity
            cardView.setVerdictHint(0)
        }
    }

    @objc
    private func swipe(_ pan: UIPanGestureRecognizer) {
        guard let cardView = pan.view as? ReviewCardView else {
            return
        }
        let translation = pan.translation(in: stackArea)
        switch pan.state {
        case .changed:
            let rotation = UIAccessibility.isReduceMotionEnabled ? 0 : translation.x / max(stackArea.bounds.width, 1) * 0.3
            cardView.transform = CGAffineTransform(translationX: translation.x, y: translation.y * 0.2).rotated(by: rotation)
            cardView.setVerdictHint(translation.x / Self.decisionDistance)
            let isPast = abs(translation.x) > Self.decisionDistance
            if isPast != isPastDecision {
                isPastDecision = isPast
                if isPast {
                    UIImpactFeedbackGenerator(style: .light, view: cardView).impactOccurred()
                }
            }

        case .ended:
            isPastDecision = false
            let velocity = pan.velocity(in: stackArea).x
            if translation.x > Self.decisionDistance || velocity > Self.decisionVelocity {
                approveTopCard()
            } else if translation.x < -Self.decisionDistance || velocity < -Self.decisionVelocity {
                snapBack(cardView)
                askRejectReason()
            } else {
                snapBack(cardView)
            }

        case .cancelled, .failed:
            isPastDecision = false
            snapBack(cardView)

        default:
            break
        }
    }

    @objc
    private func tapCard() {
        editTopCard()
    }

    private func showDecisionIfNew(_ decision: ReviewSession.Decision?) {
        guard decision != shownDecision else {
            return
        }
        shownDecision = decision
        guard let decision else {
            return
        }
        let message =
            switch decision.verdict {
            case .approved(_, let title): ContributeKitStrings.ReviewQueue.Toast.approved(title)
            case .rejected(let reason): ContributeKitStrings.ReviewQueue.Toast.rejected(reason.title)
            }
        toast.show(message, for: Self.undoSeconds) { [model] in model.forgetLastDecision() }
    }

    private func showNoticeIfNew(_ notice: ReviewSession.Notice?) {
        guard notice != shownNotice else {
            return
        }
        shownNotice = notice
        guard let notice else {
            return
        }
        let (title, subtitle) = notice.toast
        ToastView.showFailure(title, subtitle: subtitle)
        model.dismissNotice()
    }

}

// MARK: UIGestureRecognizerDelegate

extension ReviewQueueViewController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }
        let velocity = pan.velocity(in: stackArea)
        return abs(velocity.x) > abs(velocity.y)
    }
}
