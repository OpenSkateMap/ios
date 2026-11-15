import ComponentKit
import PeopleKit
import PinLayout
import UIKit

// MARK: - ReportViewController

final class ReportViewController: UIViewController {

    // MARK: Types

    nonisolated private enum Section: Hashable {
        case reasons
        case note
    }

    nonisolated private enum Item: Hashable {
        case reason(Report.Reason)
        case note
    }

    // MARK: Properties

    private let model: ReportModel
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()
    private var sending: Task<Void, Never>?
    private lazy var sendItem = UIBarButtonItem(
        primaryAction: UIAction(title: ProfileKitStrings.Report.send, image: UIImage(systemName: "checkmark")) { [weak self] _ in
            self?.send()
        }
    )
    private let sendingItem = UIBarButtonItem.spinner()

    // MARK: Lifecycle

    init(target: Report.Target) {
        model = ReportModel(target: target)
        super.init(nibName: nil, bundle: nil)
        switch target {
        case .spot: title = ProfileKitStrings.Report.Spot.title
        case .user: title = ProfileKitStrings.Report.User.title
        }
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) },
        )
        sendItem.style = .prominent
        navigationItem.rightBarButtonItem = sendItem
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        applySnapshot()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    override func updateProperties() {
        super.updateProperties()

        sendItem.isEnabled = model.canSend
        navigationItem.showRightItem(model.isSending ? sendingItem : sendItem)
        // Read here so a new choice moves the checkmark.
        _ = model.reason
        var snapshot = dataSource.snapshot()
        guard snapshot.sectionIdentifiers.contains(.reasons) else {
            return
        }
        snapshot.reconfigureItems(snapshot.itemIdentifiers(inSection: .reasons))
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: Static Functions

    static func inNavigation(target: Report.Target) -> UIViewController {
        let navigation = UINavigationController(rootViewController: ReportViewController(target: target))
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        return navigation
    }

    // MARK: Functions

    private func setupViews() {
        collectionView.keyboardDismissMode = .interactive
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.reasons, .note])
        snapshot.appendItems(model.reasons.map(Item.reason), toSection: .reasons)
        snapshot.appendItems([.note], toSection: .note)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] index, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.headerMode = .supplementary
            configuration.footerMode = self?.dataSource.sectionIdentifier(for: index) == .note ? .supplementary : .none
            return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let reasonCell = UICollectionView
            .CellRegistration<UICollectionViewListCell, Report.Reason> { [weak self] cell, _, reason in
                let isChosen = self?.model.reason == reason
                var content = UIListContentConfiguration.cell()
                content.text = reason.title
                cell.contentConfiguration = content
                cell.accessories = isChosen ? [.checkmark()] : []
                cell.accessibilityTraits = isChosen ? [.button, .selected] : .button
            }
        let noteCell = UICollectionView.CellRegistration<TextViewListCell, Item> { [weak self] cell, _, _ in
            guard let self else {
                return
            }
            cell.minimumHeight = 120
            cell.show(
                text: model.message,
                placeholder: "",
                limit: ReportModel.messageLimit,
                isMultiline: true,
                isEnabled: true,
                accessibilityLabel: ProfileKitStrings.Report.A11y.note,
            )
            cell.onChange = { [weak self] text in self?.model.message = text }
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, path in
            guard let self else {
                return
            }
            var content = UIListContentConfiguration.header()
            content.text =
                switch dataSource.sectionIdentifier(for: path.section) {
                case .reasons:
                    switch model.target {
                    case .spot: ProfileKitStrings.Report.Spot.question
                    case .user: ProfileKitStrings.Report.User.question
                    }

                case .note, nil:
                    ProfileKitStrings.Report.Note.title
                }
            header.contentConfiguration = content
        }
        let footer = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { footer, _, _ in
            var content = UIListContentConfiguration.footer()
            content.text = ProfileKitStrings.Report.footer
            footer.contentConfiguration = content
        }
        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { view, path, item in
            switch item {
            case .reason(let reason): view.dequeueConfiguredReusableCell(using: reasonCell, for: path, item: reason)
            case .note: view.dequeueConfiguredReusableCell(using: noteCell, for: path, item: item)
            }
        }
        dataSource.supplementaryViewProvider = { view, kind, path in
            kind == UICollectionView.elementKindSectionFooter
                ? view.dequeueConfiguredReusableSupplementary(using: footer, for: path)
                : view.dequeueConfiguredReusableSupplementary(using: header, for: path)
        }
        return dataSource
    }

    private func send() {
        view.endEditing(true)
        guard sending == nil, model.canSend else {
            return
        }
        sending = Task { [weak self, model] in
            defer { self?.sending = nil }
            do {
                try await model.send()
                self?.dismiss(animated: true)
                Task {
                    await ToastView().show(.icon(
                        predefinedIcon: .success,
                        title: ProfileKitStrings.Report.Thanks.title,
                        subtitle: ProfileKitStrings.Report.Thanks.message,
                    ))
                }
            } catch {
                ToastView.showFailure(ProfileKitStrings.Report.failed, subtitle: PeopleAPIError.message(for: error))
            }
        }
    }
}

// MARK: UICollectionViewDelegate

extension ReportViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        if case .reason = dataSource.itemIdentifier(for: indexPath) {
            return true
        }
        return false
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        if case .reason(let reason) = dataSource.itemIdentifier(for: indexPath) {
            model.reason = reason
        }
    }
}
