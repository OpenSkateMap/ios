import ComponentKit
import FactoryKit
import IdentifiedCollections
import ImageKit
import PinLayout
import ReviewKit
import SpotModelKit
import UIKit

// MARK: - VideoReviewViewController

final class VideoReviewViewController: UIViewController {

    // MARK: Static Properties

    private static let undoSeconds = 5.0

    // MARK: Properties

    @Injected(\.reviewSession) private var session
    @Injected(\.imageLoader) private var loader
    private let scrollView = UIScrollView().softEdges()
    private let toast = ReviewToastView()
    private var rows = [VideoReviewCard.ID: VideoReviewRowView]()
    private var shownDecision: ReviewSession.VideoDecision?
    private var shownNotice: ReviewSession.Notice?

    // MARK: Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)

        title = ContributeKitStrings.VideoReview.title
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupActions()
        Task { await session.load() }
    }

    override func updateProperties() {
        super.updateProperties()

        render(session.videoCards)
        showDecisionIfNew(session.lastVideoDecision)
        showNoticeIfNew(session.notice)
        updateEmptyState()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.pin
            .all()
        var bottom: CGFloat = 16
        for card in session.videoCards {
            guard let row = rows[card.id] else {
                continue
            }
            row.pin
                .top(bottom)
                .horizontally(view.safeAreaInsets)
                .marginHorizontal(16)
                .sizeToFit(.width)
            bottom = row.frame.maxY + 12
        }
        scrollView.contentSize = CGSize(width: view.bounds.width, height: bottom + 80)
        toast.pin
            .bottom(view.pin.safeArea.bottom + 16)
            .horizontally(view.safeAreaInsets)
            .marginHorizontal(24)
            .sizeToFit(.width)
    }

    // MARK: Functions

    private func setupViews() {
        view.backgroundColor = .systemBackground
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        view.addSubview(toast)
    }

    private func setupActions() {
        toast.onUndo = { [weak self] in
            Task { [weak self] in
                await self?.session.undoVideo()
                self?.toast.finishUndoing()
            }
        }
    }

    private func updateEmptyState() {
        guard session.videoCards.isEmpty, session.deciding.isEmpty else {
            contentUnavailableConfiguration = session.videoCards.isEmpty ? UIContentUnavailableConfiguration.loading() : nil
            return
        }
        switch session.phase {
        case .idle where !session.isQueueKnown, .loading where !session.isQueueKnown:
            contentUnavailableConfiguration = UIContentUnavailableConfiguration.loading()

        case .failed(let notice) where !session.isQueueKnown:
            var configuration = UIContentUnavailableConfiguration.empty()
            configuration.image = UIImage(systemName: "wifi.exclamationmark")
            configuration.text = ContributeKitStrings.ReviewQueue.Failed.title
            configuration.secondaryText = notice.loadFailureMessage
            var button = UIButton.Configuration.filled()
            button.title = ContributeKitStrings.ReviewQueue.Failed.retry
            button.cornerStyle = .capsule
            configuration.button = button
            configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
                guard let self else {
                    return
                }
                Task { await self.session.load() }
            }
            contentUnavailableConfiguration = configuration

        case .idle, .loading, .failed, .loaded:
            var configuration = UIContentUnavailableConfiguration.empty()
            configuration.image = UIImage(systemName: "play.rectangle")
            configuration.text = ContributeKitStrings.VideoReview.Empty.title
            configuration.secondaryText = ContributeKitStrings.VideoReview.Empty.message
            contentUnavailableConfiguration = configuration
        }
    }

    private func render(_ cards: IdentifiedArrayOf<VideoReviewCard>) {
        for (id, row) in rows where cards[id: id] == nil {
            row.removeFromSuperview()
            rows[id] = nil
        }
        for card in cards where rows[card.id] == nil {
            let row = VideoReviewRowView(card: card, loader: loader)
            row.onWatch = { UIApplication.shared.open(card.url) }
            row.onApprove = { [session, unowned row] in
                UINotificationFeedbackGenerator(view: row).notificationOccurred(.success)
                Task { await session.approveVideo(card.id) }
            }
            row.onReject = { [session, unowned row] reason in
                UIImpactFeedbackGenerator(style: .medium, view: row).impactOccurred()
                Task { await session.rejectVideo(card.id, reason: reason) }
            }
            rows[card.id] = row
            scrollView.addSubview(row)
        }
        view.setNeedsLayout()
    }

    private func showDecisionIfNew(_ decision: ReviewSession.VideoDecision?) {
        guard decision != shownDecision else {
            return
        }
        shownDecision = decision
        guard let decision else {
            return
        }
        let message =
            switch decision.verdict {
            case .approved: ContributeKitStrings.VideoReview.Toast.approved(decision.card.spotTitle)
            case .rejected(let reason): ContributeKitStrings.VideoReview.Toast.rejected(reason.title)
            }
        toast.show(message, for: Self.undoSeconds) { [session] in session.forgetLastVideoDecision() }
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
        session.dismissNotice()
    }
}

// MARK: - VideoReviewRowView

private final class VideoReviewRowView: UIView {

    // MARK: Properties

    var onWatch: (() -> Void)?
    var onApprove: (() -> Void)?
    var onReject: ((VideoRejectReason) -> Void)?

    private let thumbnailView = VideoThumbnailView()
    private let spotLabel = Label()
    private let detailLabel = Label()
    private let watchButton = UIButton(configuration: .glass())
    private let rejectButton = UIButton(configuration: .glass())
    private let approveButton = UIButton(configuration: .primaryCapsule(title: ContributeKitStrings.VideoReview.approve))

    // MARK: Lifecycle

    init(card: VideoReviewCard, loader: ImageLoader) {
        super.init(frame: .zero)

        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        thumbnailView.show(card.provider, thumbnail: card.thumbnailURL, loader: loader)
        let platform = card.provider.title
        spotLabel.text = card.spotTitle
        spotLabel.font = .preferredFont(forTextStyle: .headline)
        spotLabel.adjustsFontForContentSizeCategory = true
        spotLabel.numberOfLines = 2
        detailLabel.text = [
            card.caption.isEmpty ? nil : ContributeKitStrings.VideoReview.caption(card.caption),
            card.submitterName.map { ContributeKitStrings.VideoReview.sentBy(platform, $0) }
                ?? ContributeKitStrings.VideoReview.sentByDeletedAccount(platform),
        ]
        .compactMap(\.self).joined(separator: "\n")
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 3
        watchButton.configuration?.title = ContributeKitStrings.VideoReview.watch
        watchButton.configuration?.image = UIImage(systemName: "play.fill")
        watchButton.configuration?.imagePadding = 6
        watchButton.configuration?.cornerStyle = .capsule
        watchButton.accessibilityHint = ContributeKitStrings.VideoReview.A11y.watchHint(platform)
        watchButton.addAction(UIAction { [weak self] _ in self?.onWatch?() }, for: .primaryActionTriggered)
        rejectButton.configuration?.title = ContributeKitStrings.VideoReview.reject
        rejectButton.configuration?.baseForegroundColor = .systemRed
        rejectButton.configuration?.cornerStyle = .capsule
        rejectButton.showsMenuAsPrimaryAction = true
        let reasons = VideoRejectReason.allCases.map { reason in
            UIAction(title: reason.title) { [weak self] _ in self?.onReject?(reason) }
        }
        rejectButton.menu = UIMenu(title: ContributeKitStrings.VideoReview.rejectMenu, children: reasons)
        approveButton.addAction(UIAction { [weak self] _ in self?.onApprove?() }, for: .primaryActionTriggered)
        for button in [watchButton, rejectButton, approveButton] {
            button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10)
        }
        for view in [thumbnailView, spotLabel, detailLabel, watchButton, rejectButton, approveButton] {
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

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        let inset: CGFloat = 16
        thumbnailView.pin
            .top(inset)
            .start(inset)
            .size(VideoThumbnailView.size)
        spotLabel.pin
            .after(of: thumbnailView, aligned: .top)
            .end(inset)
            .marginStart(12)
            .sizeToFit(.width)
        detailLabel.pin
            .below(of: spotLabel, aligned: .start)
            .end(inset)
            .marginTop(2)
            .sizeToFit(.width)
        var top = max(thumbnailView.frame.maxY, detailLabel.frame.maxY) + 14
        let buttons = [watchButton, rejectButton, approveButton]
        let rowWidth = (width - inset * 2 - 16) / 3
        let fitsInRow = buttons.allSatisfy {
            $0.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 44)).width <= rowWidth
        }
        if fitsInRow {
            let height = buttons.map { max(44, ceil($0.sizeThatFits(CGSize(width: rowWidth, height: 0)).height)) }.max() ?? 44
            var start = inset
            for button in buttons {
                button.pin
                    .top(top)
                    .start(start)
                    .width(rowWidth)
                    .height(height)
                start += rowWidth + 8
            }
            return top + height + inset
        }
        let fullWidth = width - inset * 2
        for button in buttons {
            let height = max(44, ceil(button.sizeThatFits(CGSize(width: fullWidth, height: 0)).height))
            button.frame = CGRect(x: inset, y: top, width: fullWidth, height: height)
            top += height + 8
        }
        return top - 8 + inset
    }
}
