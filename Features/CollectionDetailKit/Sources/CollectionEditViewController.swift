import CollectionsKit
import ComponentKit
import PinLayout
import SpotModelKit
import UIKit

// MARK: - CollectionEditViewController

final class CollectionEditViewController: UIViewController {

    // MARK: Types

    nonisolated private enum Section: Int, CaseIterable {
        case preview
        case name
        case about
    }

    // MARK: Properties

    private let model: CollectionEditModel
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()
    private lazy var photoPicker = PhotoPicker(presenter: self) { [weak self] files in
        Task { @MainActor [weak self] in
            do {
                guard let file = files.first ?? nil else {
                    throw CollectionEditModel.PhotoError.unreadable
                }
                try await self?.model.choosePhoto(file)
            } catch {
                ToastView.showFailure(CollectionDetailKitStrings.Edit.photoFailed)
            }
        }
    }

    private lazy var cancelItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
        self?.cancel()
    })
    private lazy var doneItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
        self?.save()
    })
    private lazy var savingItem = UIBarButtonItem.spinner()

    private var shownSaving = false

    // MARK: Lifecycle

    init(model: CollectionEditModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        title = CollectionDetailKitStrings.Edit.title
        navigationItem.leftBarButtonItem = cancelItem
        navigationItem.rightBarButtonItem = doneItem
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
    }

    override func updateProperties() {
        super.updateProperties()

        let isSaving = model.isSaving
        navigationItem.rightBarButtonItem = isSaving ? savingItem : doneItem
        doneItem.isEnabled = model.canSave && model.hasChanges && !model.isPreparingPhoto
        cancelItem.isEnabled = !isSaving
        isModalInPresentation = model.hasChanges || isSaving
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(isSaving == shownSaving ? [.preview] : snapshot.itemIdentifiers)
        shownSaving = isSaving
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    // MARK: Overrides

    override func accessibilityPerformEscape() -> Bool {
        if cancelItem.isEnabled {
            cancel()
        }
        return true
    }

    // MARK: Static Functions

    private static func header(for section: Section) -> String? {
        switch section {
        case .preview: nil
        case .name: CollectionDetailKitStrings.Edit.name
        case .about: CollectionDetailKitStrings.Edit.about
        }
    }

    // MARK: Functions

    private func setupViews() {
        view.backgroundColor = .systemGroupedBackground
        collectionView.backgroundColor = .clear
        collectionView.keyboardDismissMode = .interactive
        view.addSubview(collectionView)
        var snapshot = NSDiffableDataSourceSnapshot<Section, Section>()
        let sections = Section.allCases.filter { $0 != .name || model.kind == .custom }
        snapshot.appendSections(sections)
        for section in sections {
            snapshot.appendItems([section], toSection: section)
        }
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func cancel() {
        dismiss(animated: true)
    }

    private func save() {
        view.endEditing(true)
        Task { [weak self, model] in
            do {
                try await model.save()
                self?.dismiss(animated: true)
            } catch {
                CollectionFailure.show(CollectionDetailKitStrings.Edit.saveFailed, error)
            }
        }
    }

    private func photoMenu() -> UIMenu {
        let remove = UIAction(
            title: CollectionDetailKitStrings.Edit.removePhoto,
            image: UIImage(systemName: "trash"),
            attributes: .destructive,
        ) { [weak self] _ in
            self?.model.photo = .none
        }
        let removing: [UIMenuElement] = model.photo == .none ? [] : [remove]
        return UIMenu(children: [UIMenu(options: .displayInline, children: photoPicker.actions())] + removing)
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] index, environment in
            let section = self?.dataSource.sectionIdentifier(for: index)
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.headerMode = section.flatMap(Self.header) == nil ? .none : .supplementary
            if section == .preview {
                configuration.backgroundColor = .clear
            }
            return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Section> {
        let preview = UICollectionView.CellRegistration<CollectionPreviewCell, Section> { [weak self] cell, _, _ in
            guard let self else {
                return
            }
            cell.show(
                name: model.kind.title(named: model.name),
                backdrop: model.backdrop,
                photoMenu: photoMenu(),
                isPreparingPhoto: model.isPreparingPhoto,
                isEnabled: !model.isSaving,
            )
            cell.backgroundConfiguration = .clear()
        }
        let text = UICollectionView.CellRegistration<TextViewListCell, Section> { [weak self] cell, _, section in
            guard let self else {
                return
            }
            let isName = section == .name
            cell.show(
                text: isName ? model.name : model.about,
                placeholder: isName
                    ? CollectionDetailKitStrings.Edit.namePlaceholder
                    : CollectionDetailKitStrings.Edit.aboutPlaceholder,
                limit: isName ? 60 : 300,
                isMultiline: !isName,
                isEnabled: !model.isSaving,
            )
            cell.onChange = { [weak self] value in
                guard let self else {
                    return
                }
                switch section {
                case .name: model.name = value
                default: model.about = value
                }
            }
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, path in
            var content = UIListContentConfiguration.header()
            content.text = self?.dataSource.sectionIdentifier(for: path.section).flatMap(Self.header)
            header.contentConfiguration = content
        }
        let dataSource = UICollectionViewDiffableDataSource<
            Section,
            Section,
        >(collectionView: collectionView) { view, path, section in
            switch section {
            case .preview: view.dequeueConfiguredReusableCell(using: preview, for: path, item: section)
            case .name, .about: view.dequeueConfiguredReusableCell(using: text, for: path, item: section)
            }
        }
        dataSource.supplementaryViewProvider = { (view: UICollectionView, _: String, path: IndexPath) in
            view.dequeueConfiguredReusableSupplementary(using: header, for: path)
        }
        return dataSource
    }
}
