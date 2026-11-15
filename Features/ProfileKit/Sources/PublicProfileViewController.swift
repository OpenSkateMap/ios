import ComponentKit
import FactoryKit
import PeopleKit
import PinLayout
import UIKit

final class PublicProfileViewController: UIViewController {

    // MARK: Properties

    private let model: PublicProfileModel
    private let scrollView = UIScrollView().softEdges()
    private let header = ProfileHeaderView()
    private let blockedLabel = Label()
    private let statusLabel = Label()
    private let retryButton = UIButton(configuration: .gray())
    private var action: Task<Void, Never>?
    private lazy var moreItem: UIBarButtonItem = {
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: [
            UIDeferredMenuElement.uncached { [weak self] completion in completion(self?.moreActions() ?? []) }
        ]))
        more.accessibilityLabel = ProfileKitStrings.PublicProfile.A11y.more
        return more
    }()

    private let busyItem = UIBarButtonItem.spinner()

    // MARK: Lifecycle

    init(userID: String) {
        model = PublicProfileModel(userID: userID)
        super.init(nibName: nil, bundle: nil)
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)
        scrollView.addSubview(header)
        header.onOpenURL = { [weak self] in self?.view.window?.windowScene?.open($0, options: nil) }

        blockedLabel.text = ProfileKitStrings.PublicProfile.blocked
        blockedLabel.font = .preferredFont(forTextStyle: .footnote)
        blockedLabel.adjustsFontForContentSizeCategory = true
        blockedLabel.textColor = .secondaryLabel
        blockedLabel.textAlignment = .center
        blockedLabel.numberOfLines = 0
        scrollView.addSubview(blockedLabel)

        statusLabel.font = .preferredFont(forTextStyle: .body)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        var retry = UIButton.Configuration.gray()
        retry.title = ProfileKitStrings.Common.tryAgain
        retry.cornerStyle = .capsule
        retryButton.configuration = retry
        retryButton.addAction(UIAction { [weak self] _ in self?.load() }, for: .primaryActionTriggered)
        view.addSubview(statusLabel)
        view.addSubview(retryButton)

        if navigationController?.viewControllers.first === self {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                systemItem: .done,
                primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) },
            )
        }
        load()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.pin
            .all()
        let margins = view.layoutMargins
        header.pin
            .top(16)
            .horizontally(margins)
            .sizeToFit(.width)
        var bottom = header.frame.maxY
        if !blockedLabel.isHidden {
            blockedLabel.pin
                .below(of: header)
                .horizontally(margins)
                .marginTop(24)
                .sizeToFit(.width)
            bottom = blockedLabel.frame.maxY
        }
        scrollView.contentSize = CGSize(width: view.bounds.width, height: bottom + 40)
        statusLabel.pin
            .vCenter(-24)
            .horizontally(UIEdgeInsets(top: 0, left: margins.left * 2, bottom: 0, right: margins.right * 2))
            .sizeToFit(.width)
        retryButton.pin
            .below(of: statusLabel, aligned: .center)
            .marginTop(16)
            .sizeToFit()
    }

    override func updateProperties() {
        super.updateProperties()

        let profile = model.profile
        title = profile?.username.map { "@\($0)" } ?? profile?.name
        if let profile {
            header.show(profile)
        } else {
            header.showPlaceholder(name: nil, badge: nil)
        }
        blockedLabel.isHidden = profile?.blockedByMe != true
        switch model.phase {
        case .unavailable:
            scrollView.isHidden = true
            statusLabel.text = ProfileKitStrings.PublicProfile.unavailable
            statusLabel.isHidden = false
            retryButton.isHidden = true

        case .failed(let message) where profile == nil:
            scrollView.isHidden = true
            statusLabel.text = message
            statusLabel.isHidden = false
            retryButton.isHidden = false
            retryButton.configuration?.showsActivityIndicator = model.isLoading
            retryButton.isEnabled = !model.isLoading

        case .loading, .loaded, .failed:
            scrollView.isHidden = false
            statusLabel.isHidden = true
            retryButton.isHidden = true
        }
        // A first load spins where More will appear, so nothing moves once it does.
        let isFirstLoad = profile == nil && model.phase == .loading
        let showsMore = profile != nil && !model.isYou && model.phase != .unavailable
        let rightItem: UIBarButtonItem? =
            if model.isChangingBlock || isFirstLoad {
                busyItem
            } else if showsMore {
                moreItem
            } else {
                nil
            }
        navigationItem.showRightItem(rightItem)
        view.setNeedsLayout()
    }

    // MARK: Functions

    private func load() {
        Task { [model] in await model.load() }
    }

    private func moreActions() -> [UIMenuElement] {
        guard let profile = model.profile else {
            return []
        }
        let block =
            if profile.blockedByMe {
                UIAction(
                    title: ProfileKitStrings.PublicProfile.More.unblock,
                    image: UIImage(systemName: "hand.raised.slash"),
                ) { [weak self] _ in
                    self?.changeBlock(to: false)
                }
            } else {
                UIAction(
                    title: ProfileKitStrings.PublicProfile.More.block,
                    image: UIImage(systemName: "hand.raised"),
                    attributes: .destructive,
                ) { [weak self] _ in
                    self?.confirmBlock(profile)
                }
            }
        let report = UIAction(
            title: ProfileKitStrings.PublicProfile.More.report,
            image: UIImage(systemName: "flag"),
        ) { [weak self] _ in
            self?.present(ReportViewController.inNavigation(target: .user(id: profile.id)), animated: true)
        }
        let collections = UIAction(
            title: ProfileKitStrings.PublicProfile.More.collections,
            image: UIImage(systemName: "rectangle.stack"),
        ) { [weak self] _ in
            if let list = Container.shared.userCollectionsScreen(profile.id) {
                self?.navigationController?.pushViewController(list, animated: true)
            }
        }
        return [UIMenu(options: .displayInline, children: [collections]), report, block]
    }

    private func confirmBlock(_ profile: PublicProfile) {
        let alert = UIAlertController(
            title: ProfileKitStrings.PublicProfile.Block.title(profile.name),
            message: ProfileKitStrings.PublicProfile.Block.message,
            preferredStyle: .alert,
        )
        alert.addAction(UIAlertAction(
            title: ProfileKitStrings.PublicProfile.Block.confirm,
            style: .destructive,
        ) { [weak self] _ in
            self?.changeBlock(to: true)
        })
        alert.addAction(UIAlertAction(title: ProfileKitStrings.Common.cancel, style: .cancel))
        present(alert, animated: true)
    }

    private func changeBlock(to blocked: Bool) {
        guard action == nil else {
            return
        }
        action = Task { [weak self, model] in
            defer { self?.action = nil }
            do {
                try await model.setBlocked(blocked)
            } catch {
                ToastView.showFailure(
                    blocked ? ProfileKitStrings.PublicProfile.Block.failed : ProfileKitStrings.PublicProfile.Unblock.failed,
                    subtitle: PeopleAPIError.message(for: error),
                )
            }
        }
    }
}
