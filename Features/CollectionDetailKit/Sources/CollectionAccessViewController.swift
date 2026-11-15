import AppLinkKit
import CollectionsKit
import ComponentKit
import IdentifiedCollections
import PinLayout
import SpotModelKit
import UIKit

// MARK: - CollectionAccessViewController

final class CollectionAccessViewController: UIViewController {

    // MARK: Types

    nonisolated private enum Section: Hashable {
        case visibility
        case requests
        case people
        case link
    }

    nonisolated private enum Item: Hashable {
        case visibility(CollectionVisibility)
        case request(String)
        case addPeople
        case owner
        case member(String)
        case invite(String)
        case copyLink
        case shareLink
        case status
    }

    // MARK: Computed Properties

    private var access: CollectionAccess? {
        if case .loaded(let access) = model.phase {
            access
        } else {
            nil
        }
    }

    private var link: URL {
        AppLink.collection(id: model.collectionID).url
    }

    // MARK: Properties

    private let model: CollectionAccessModel
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()
    private var shownPhase: CollectionAccessModel.Phase?
    private var shownChanges = Set<CollectionAccessModel.Change>()

    // MARK: Lifecycle

    convenience init(collectionID: String, role: CollectionRole, draft: CollectionDraft, privateSpotCount: Int) {
        self.init(model: CollectionAccessModel(
            collectionID: collectionID,
            role: role,
            draft: draft,
            privateSpotCount: privateSpotCount,
        ))
    }

    init(model: CollectionAccessModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        title = CollectionDetailKitStrings.Access.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        Task { [model] in await model.load() }
    }

    override func updateProperties() {
        super.updateProperties()

        guard model.phase != shownPhase || model.changes != shownChanges else {
            return
        }
        shownPhase = model.phase
        shownChanges = model.changes
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        let manages = model.managesPeople
        if manages {
            snapshot.appendSections([.visibility])
            snapshot.appendItems([.visibility(.private), .visibility(.public)], toSection: .visibility)
        }
        if let requests = access?.requests, !requests.isEmpty {
            snapshot.appendSections([.requests])
            snapshot.appendItems(requests.map { .request($0.id) }, toSection: .requests)
        }
        snapshot.appendSections([.people])
        switch model.phase {
        case .loaded(let access):
            snapshot.appendItems(
                (manages ? [.addPeople] : []) + [.owner] + access.members.map { .member($0.id) }
                    + access.invites.map { .invite($0.id) },
                toSection: .people,
            )

        case .loading, .failed:
            snapshot.appendItems([.status], toSection: .people)
        }
        if model.showsLinks {
            snapshot.appendSections([.link])
            snapshot.appendItems([.copyLink, .shareLink], toSection: .link)
        }
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        // Footers aren't items: a snapshot never reconfigures them, so the visible ones are set again.
        dataSource.apply(snapshot, animatingDifferences: view.window != nil) { [weak self] in self?.refreshFooters() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    // MARK: Functions

    private func setupViews() {
        view.backgroundColor = .systemGroupedBackground
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func choose(_ visibility: CollectionVisibility) {
        guard let confirmation = model.confirmation(for: visibility) else {
            return
        }
        let alert = UIAlertController(title: confirmation.title, message: confirmation.message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: confirmation.confirmTitle, style: .default) { [weak self] _ in
            self?.run(CollectionDetailKitStrings.Access.visibilityFailed) { try await $0.confirm(confirmation) }
        })
        alert.addAction(UIAlertAction(title: CollectionDetailKitStrings.Alert.cancel, style: .cancel))
        present(alert, animated: true)
    }

    private func pickRole(from item: Item) {
        guard let path = dataSource.indexPath(for: item), let row = collectionView.cellForItem(at: path) else {
            return
        }
        let roles = CollectionMemberRole.allCases.map { role in
            ActionPopoverController.Action(
                title: CollectionDetailKitStrings.Access.AddPeople.inviteAs(role.title),
                detail: role.detail,
                image: UIImage(systemName: role.symbolName),
            ) { [weak self] in self?.addPeople(as: role) }
        }
        present(ActionPopoverController(actions: roles, from: row), animated: true)
    }

    private func addPeople(as role: CollectionMemberRole) {
        let alert = UIAlertController(
            title: CollectionDetailKitStrings.Access.AddPeople.inviteAs(role.title),
            message: CollectionDetailKitStrings.Access.AddPeople.message,
            preferredStyle: .alert,
        )
        let invite = UIAlertAction(title: CollectionDetailKitStrings.Access.AddPeople.invite, style: .default) {
            [weak self, weak alert] _ in
            let typed = alert?.textFields?.first?.text ?? ""
            self?.run(
                CollectionDetailKitStrings.Access.AddPeople.failed,
                notFound: CollectionDetailKitStrings.Access.unknownUsername,
            ) { try await $0.invite(typed, as: role) }
        }
        invite.isEnabled = false
        alert.addTextField { [weak invite] field in
            field.placeholder = CollectionDetailKitStrings.Access.AddPeople.placeholder
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.keyboardType = .emailAddress
            field.runsLeftToRight()
            field.addAction(UIAction { [weak field] _ in
                invite?.isEnabled = CollectionInvitee(typed: field?.text ?? "") != nil
            }, for: .editingChanged)
        }
        alert.addAction(UIAlertAction(title: CollectionDetailKitStrings.Alert.cancel, style: .cancel))
        alert.addAction(invite)
        alert.preferredAction = invite
        present(alert, animated: true)
    }

    private func roleMenu(for member: CollectionAccess.Member) -> UIMenu {
        let roles = UIMenu(
            options: [.displayInline, .singleSelection],
            children: CollectionMemberRole.allCases.reversed().map { role in
                UIAction(
                    title: role.title,
                    subtitle: role.detail,
                    image: UIImage(systemName: role.symbolName),
                    state: role == member.role ? .on : .off,
                ) { [weak self] _ in
                    self?.run(CollectionDetailKitStrings.Access.People.roleFailed) { try await $0.setRole(role, of: member) }
                }
            },
        )
        let remove = UIAction(
            title: CollectionDetailKitStrings.Access.People.removeFromCollection,
            image: UIImage(systemName: "person.crop.circle.badge.minus"),
            attributes: .destructive,
        ) { [weak self] _ in
            self?.run(CollectionDetailKitStrings.Access.People.removeFailed) { try await $0.remove(member) }
        }
        return UIMenu(children: [roles, UIMenu(options: .displayInline, children: [remove])])
    }

    private func answerButton(for request: CollectionAccess.Request) -> UIButton {
        var configuration = UIButton.Configuration.tinted()
        configuration.title = CollectionDetailKitStrings.Access.Requests.letIn
        configuration.cornerStyle = .capsule
        configuration.buttonSize = .small
        configuration.showsActivityIndicator = model.changes.contains(.request(request.id))
        let button = UIButton(configuration: configuration)
        let roles = CollectionMemberRole.allCases.map { role in
            UIAction(
                title: CollectionDetailKitStrings.Access.Requests.letInAs(role.title),
                subtitle: role.detail,
                image: UIImage(systemName: role.symbolName),
            ) { [weak self] _ in
                self?.run(CollectionDetailKitStrings.Access.Requests.failed) { try await $0.letIn(request, as: role) }
            }
        }
        let decline = UIAction(
            title: CollectionDetailKitStrings.Access.Requests.decline,
            image: UIImage(systemName: "xmark"),
            attributes: .destructive,
        ) { [weak self] _ in
            self?.run(CollectionDetailKitStrings.Access.Requests.failed) { try await $0.decline(request) }
        }
        button.menu = UIMenu(children: [UIMenu(options: .displayInline, children: roles), decline])
        button.showsMenuAsPrimaryAction = true
        button.isEnabled = !model.changes.contains(.request(request.id))
        button.sizeToFit()
        return button
    }

    private func shareLink(from item: Item) {
        let activity = UIActivityViewController(activityItems: [link], applicationActivities: nil)
        if let path = dataSource.indexPath(for: item) {
            activity.popoverPresentationController?.sourceItem = collectionView.cellForItem(at: path)
        }
        present(activity, animated: true)
    }

    private func run(_ failureTitle: String,
                     notFound: String? = nil,
                     _ operation: @escaping (CollectionAccessModel) async throws -> Void) {
        Task { [model] in
            do {
                try await operation(model)
            } catch {
                CollectionFailure.show(failureTitle, error, notFound: notFound)
            }
        }
    }

    private func refreshFooters() {
        let kind = UICollectionView.elementKindSectionFooter
        for path in collectionView.indexPathsForVisibleSupplementaryElements(ofKind: kind) {
            let footer = collectionView.supplementaryView(forElementKind: kind, at: path) as? UICollectionViewListCell
            footer?.contentConfiguration = footerContent(for: path.section)
        }
    }

    private func footerContent(for sectionIndex: Int) -> UIListContentConfiguration {
        var content = UIListContentConfiguration.footer()
        content.text = footer(for: dataSource.sectionIdentifier(for: sectionIndex))
        return content
    }

    private func footer(for section: Section?) -> String? {
        switch section {
        case .visibility:
            model.draft.visibility == .public
                ? CollectionDetailKitStrings.Access.Public.footer
                : CollectionDetailKitStrings.Access.Private.footer

        case .people:
            model.managesPeople && access.map { $0.members.isEmpty && $0.invites.isEmpty } == true
                ? CollectionDetailKitStrings.Access.People.footer
                : nil

        case .requests, .link, nil: nil
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] index, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            let section = self?.dataSource.sectionIdentifier(for: index)
            configuration.footerMode = .supplementary
            configuration.headerMode = section == .people || section == .requests ? .supplementary : .none
            configuration.trailingSwipeActionsConfigurationProvider = { [weak self] path in
                self?.removeAction(at: path)
            }
            return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
        }
    }

    private func removeAction(at path: IndexPath) -> UISwipeActionsConfiguration? {
        guard let access, model.managesPeople else {
            return nil
        }
        switch dataSource.itemIdentifier(for: path) {
        case .member(let id):
            guard let member = access.members[id: id], !model.changes.contains(.member(id)) else {
                return nil
            }
            return UISwipeActionsConfiguration(actions: [UIContextualAction(
                style: .destructive,
                title: CollectionDetailKitStrings.Access.People.remove,
            ) { [weak self] _, _, done in
                self?.run(CollectionDetailKitStrings.Access.People.removeFailed) { try await $0.remove(member) }
                done(true)
            }])

        case .invite(let id):
            guard let invite = access.invites[id: id], !model.changes.contains(.invite(id)) else {
                return nil
            }
            return UISwipeActionsConfiguration(actions: [UIContextualAction(
                style: .destructive,
                title: CollectionDetailKitStrings.Access.People.cancelInvite,
            ) { [weak self] _, _, done in
                self?.run(CollectionDetailKitStrings.Access.People.cancelInviteFailed) { try await $0.cancel(invite) }
                done(true)
            }])

        default:
            return nil
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            guard let self else {
                return
            }
            cell.contentConfiguration = content(for: item)
            cell.accessories = accessories(for: item)
        }
        let addPeople = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            guard let self else {
                return
            }
            cell.contentConfiguration = content(for: item)
            let isAdding = model.changes.contains(.addPeople)
            cell.accessories = isAdding ? [.spinner()] : []
            cell.accessibilityTraits = isAdding ? [.button, .notEnabled] : .button
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, path in
            var content = UIListContentConfiguration.header()
            content.text = self?.dataSource.sectionIdentifier(for: path.section) == .requests
                ? CollectionDetailKitStrings.Access.Requests.header
                : CollectionDetailKitStrings.Access.People.header
            header.contentConfiguration = content
        }
        let footer = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] footer, _, path in
            footer.contentConfiguration = self?.footerContent(for: path.section)
        }
        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { view, path, item in
            view.dequeueConfiguredReusableCell(using: item == .addPeople ? addPeople : cell, for: path, item: item)
        }
        dataSource.supplementaryViewProvider = { view, kind, path in
            kind == UICollectionView.elementKindSectionHeader
                ? view.dequeueConfiguredReusableSupplementary(using: header, for: path)
                : view.dequeueConfiguredReusableSupplementary(using: footer, for: path)
        }
        return dataSource
    }

    private func content(for item: Item) -> UIListContentConfiguration {
        var content = UIListContentConfiguration.cell()
        switch item {
        case .visibility(let visibility):
            content = .subtitleCell()
            content.text = visibility == .private
                ? CollectionDetailKitStrings.Visibility.private
                : CollectionDetailKitStrings.Visibility.public
            content.secondaryText = visibility == .private
                ? CollectionDetailKitStrings.Access.Private.detail
                : CollectionDetailKitStrings.Access.Public.detail
            content.secondaryTextProperties.color = .secondaryLabel
            content.image = UIImage(systemName: visibility == .private ? "lock.fill" : "globe")

        case .addPeople:
            content.text = CollectionDetailKitStrings.Access.People.add
            content.textProperties.color = model.changes.contains(.addPeople) ? .secondaryLabel : .tintColor
            content.image = UIImage(systemName: "person.crop.circle.badge.plus")

        case .owner:
            content = person(access?.owner)

        case .member(let id):
            content = person(access?.members[id: id]?.person)

        case .request(let id):
            content = person(access?.requests[id: id]?.person)

        case .invite(let id):
            let invite = access?.invites[id: id]
            content = .subtitleCell()
            content.text = invite?.person?.name ?? invite?.email
            content.secondaryText = invite.map { CollectionDetailKitStrings.Access.People.invitedAs($0.role.title) }
            content.secondaryTextProperties.color = .secondaryLabel
            content.image = UIImage(systemName: invite?.person == nil ? "envelope.fill" : "person.crop.circle.badge.clock")
            content.imageProperties.tintColor = .secondaryLabel

        case .copyLink:
            content.text = CollectionDetailKitStrings.Access.Link.copy
            content.image = UIImage(systemName: "link")

        case .shareLink:
            content.text = CollectionDetailKitStrings.Access.Link.share
            content.image = UIImage(systemName: "square.and.arrow.up")

        case .status:
            content.text = model.phase == .failed
                ? CollectionDetailKitStrings.Access.People.loadFailed
                : CollectionDetailKitStrings.Access.People.loading
            content.textProperties.color = .secondaryLabel
        }
        return content
    }

    private func person(_ person: CollectionAccess.Person?) -> UIListContentConfiguration {
        var content = UIListContentConfiguration.subtitleCell()
        content.text = person?.name
        content.secondaryText = person?.username.map { "@\($0)" }
        content.secondaryTextProperties.color = .secondaryLabel
        content.image = UIImage(systemName: "person.crop.circle.fill")
        content.imageProperties.tintColor = .secondaryLabel
        return content
    }

    private func accessories(for item: Item) -> [UICellAccessory] {
        switch item {
        case .visibility(let visibility) where visibility == model.changingVisibility:
            [.spinner()]
        case .visibility(let visibility):
            model.changingVisibility == nil && visibility == model.draft.visibility ? [.checkmark()] : []
        case .owner:
            [.label(text: CollectionDetailKitStrings.Role.owner)]
        case .member(let id) where model.changes.contains(.member(id)):
            [.spinner()]
        case .member(let id):
            access?.members[id: id].map(memberAccessories) ?? []
        case .invite(let id) where model.changes.contains(.invite(id)):
            [.spinner()]
        case .request(let id):
            access?.requests[id: id].map(requestAccessories) ?? []
        case .status where model.phase == .loading:
            [.spinner()]
        default:
            []
        }
    }

    private func memberAccessories(_ member: CollectionAccess.Member) -> [UICellAccessory] {
        let role = UICellAccessory.label(text: member.role.title)
        return model.managesPeople ? [role, .popUpMenu(roleMenu(for: member))] : [role]
    }

    private func requestAccessories(_ request: CollectionAccess.Request) -> [UICellAccessory] {
        [.customView(configuration: .init(customView: answerButton(for: request), placement: .trailing()))]
    }
}

// MARK: UICollectionViewDelegate

extension CollectionAccessViewController: UICollectionViewDelegate {
    func collectionView(_: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .member(let id): model.managesPeople && !model.changes.contains(.member(id))
        case .owner, .invite, .request, nil: false
        case .status: model.phase == .failed
        case .visibility: model.changingVisibility == nil
        case .addPeople: !model.changes.contains(.addPeople)
        case .copyLink, .shareLink: true
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        switch item {
        case .visibility(let visibility): choose(visibility)
        case .copyLink: UIPasteboard.general.url = link
        case .shareLink: shareLink(from: item)
        case .addPeople: pickRole(from: item)
        case .status: Task { [model] in await model.load() }
        case .owner, .member, .invite, .request: break
        }
    }
}

// MARK: - CollectionAccessModel.VisibilityConfirmation

extension CollectionAccessModel.VisibilityConfirmation {
    fileprivate var title: String {
        switch self {
        case .makePublic: CollectionDetailKitStrings.Access.MakePublic.title
        case .makePrivate: CollectionDetailKitStrings.Access.MakePrivate.title
        }
    }

    fileprivate var message: String {
        switch self {
        case .makePublic(let privateSpotCount) where privateSpotCount > 0:
            CollectionDetailKitStrings.Access.MakePublic.privateSpotsMessage(privateSpotCount)
        case .makePublic: CollectionDetailKitStrings.Access.MakePublic.message
        case .makePrivate: CollectionDetailKitStrings.Access.MakePrivate.message
        }
    }

    fileprivate var confirmTitle: String {
        switch self {
        case .makePublic: CollectionDetailKitStrings.Access.MakePublic.confirm
        case .makePrivate: CollectionDetailKitStrings.Access.MakePrivate.confirm
        }
    }
}
