import ComponentKit
import ContributionsKit
import IdentifiedCollections
import PhotoUploadKit
import PinLayout
import UIKit

// MARK: - NewSpotCoverView

/// New Spot's photos: the cover on top and the rest under it, in one collection view so a photo can move between the
/// two sizes. A long press arranges them as the Home Screen does: they jiggle and show remove buttons, and the photo
/// pressed follows the finger, the others making room; one moved to the cover grows into it and the old cover
/// shrinks into the first place below.
final class NewSpotCoverView: UIView {

    // MARK: Static Properties

    private static let addSide: CGFloat = 48

    // MARK: Properties

    var addPhotosMenu: UIMenu? {
        didSet {
            emptyButton.menu = addPhotosMenu
            addButton.menu = addPhotosMenu
        }
    }

    /// A photo tapped, with its cell to anchor what it opens.
    var onSelectPhoto: ((_ id: UUID, _ cell: UIView) -> Void)?
    /// A photo dragged to another place; the first is the cover.
    var onMovePhoto: ((_ id: UUID, _ index: Int) -> Void)?
    var onRemovePhoto: ((UUID) -> Void)?
    /// Arranging began or ended; the screen offers Done while it lasts.
    var onArrangingChange: (() -> Void)?

    private(set) var isArranging = false

    private let emptyButton = UIButton(type: .custom)
    private let emptyGlyph = UIImageView(image: UIImage(systemName: "photo.badge.plus"))
    private let emptyLabel = Label()
    private let addButton = UIButton(configuration: .glass())
    private lazy var photosView = ReorderableCollectionView(frame: .zero, collectionViewLayout: NewSpotPhotosLayout())
        .softEdges()
    private lazy var dataSource = makeDataSource()
    private var photos = IdentifiedArrayOf<NewSpotForm.Photo>()
    private var canAddMore = true
    private var thumbnails = [UUID: UIImage]()
    private var decoding = [UUID: Task<Void, Never>]()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        emptyButton.layer.cornerRadius = 28
        emptyButton.layer.cornerCurve = .continuous
        emptyButton.backgroundColor = .tertiarySystemFill
        emptyButton.showsMenuAsPrimaryAction = true
        emptyButton.accessibilityLabel = ContributeKitStrings.NewSpotCover.addPhotos
        emptyGlyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .largeTitle)
        emptyGlyph.tintColor = .secondaryLabel
        emptyGlyph.contentMode = .center
        emptyGlyph.isUserInteractionEnabled = false
        emptyLabel.text = ContributeKitStrings.NewSpotCover.addPhotos
        emptyLabel.font = .preferredFont(forTextStyle: .headline)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = .secondaryLabel
        emptyLabel.textAlignment = .center
        emptyLabel.linesAtAccessibilitySizes = 0
        emptyLabel.isUserInteractionEnabled = false
        addButton.configuration?.image = UIImage(systemName: "photo.badge.plus")
        addButton.configuration?.cornerStyle = .capsule
        addButton.accessibilityLabel = ContributeKitStrings.NewSpotCover.addPhotos
        addButton.showsMenuAsPrimaryAction = true
        photosView.backgroundColor = .clear
        photosView.isScrollEnabled = false
        photosView.clipsToBounds = false
        photosView.delegate = self
        photosView.reorderDelegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:)))
        tap.cancelsTouchesInView = false
        photosView.addGestureRecognizer(tap)
        emptyButton.addSubview(emptyGlyph)
        emptyButton.addSubview(emptyLabel)
        for view in [emptyButton, photosView, addButton] {
            addSubview(view)
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionChanged),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil,
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        for task in decoding.values {
            task.cancel()
        }
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Static Functions

    private static func problem(_ photo: NewSpotForm.Photo) -> (text: String, color: UIColor)? {
        guard case .new(let added) = photo.source else {
            return nil
        }
        return switch added.state {
        case .failed: (ContributeKitStrings.NewSpotCover.Problem.unreadable, .systemRed)
        case .preparing: nil
        case .ready: added.credit.isComplete ? nil : (ContributeKitStrings.NewSpotCover.Problem.creditNeeded, .systemOrange)
        }
    }

    private static func credit(_ photo: NewSpotForm.Photo) -> String? {
        switch photo.source {
        case .stored(let stored):
            return stored.creditText

        case .new(let added):
            guard added.prepared != nil, added.credit.isComplete else {
                return nil
            }
            return added.credit.takenBySubmitter
                ? ContributeKitStrings.NewSpotCover.Credit.mine
                : ContributeKitStrings.NewSpotCover.Credit.someoneElse(added.credit.trimmedName)
        }
    }

    @concurrent
    private nonisolated static func thumbnail(of jpeg: Data) async -> UIImage? {
        await UIImage(data: jpeg)?.byPreparingThumbnail(ofSize: CGSize(width: 900, height: 900))
    }

    // MARK: Functions

    func show(_ photos: IdentifiedArrayOf<NewSpotForm.Photo>, canAddMore: Bool) {
        self.photos = photos
        self.canAddMore = canAddMore
        isHidden = photos.isEmpty && !canAddMore
        thumbnails = thumbnails.filter { photos[id: $0.key] != nil }
        for (id, task) in decoding where photos[id: id] == nil {
            task.cancel()
            decoding[id] = nil
        }
        for photo in photos where thumbnails[photo.id] == nil && decoding[photo.id] == nil {
            if let jpeg = photo.added?.prepared?.jpeg {
                decodeThumbnail(of: photo.id, from: jpeg)
            }
        }
        emptyButton.isHidden = !photos.isEmpty
        photosView.isHidden = photos.isEmpty
        if photos.isEmpty {
            setArranging(false)
        }
        addButton.isHidden = photos.isEmpty || !canAddMore
        // A drag under way keeps its own order; the photos settle once it ends.
        if !photosView.isReordering {
            let shown = Set(dataSource.snapshot().itemIdentifiers)
            var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
            snapshot.appendSections([0])
            snapshot.appendItems(photos.map(\.id))
            snapshot.reconfigureItems(photos.map(\.id).filter(shown.contains))
            dataSource.apply(snapshot, animatingDifferences: window != nil)
        }
        setNeedsLayout()
    }

    func endArranging() {
        setArranging(false)
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        let side = NewSpotPhotosLayout.coverSide(width: width)
        emptyButton.pin
            .top()
            .hCenter()
            .size(side)
        if traitCollection.preferredContentSizeCategory.isAccessibilityCategory {
            let labelHeight = emptyLabel.sizeThatFits(CGSize(width: side, height: .greatestFiniteMagnitude)).height
            emptyGlyph.pin
                .top(max((side - 44 - 6 - labelHeight) / 2, 0))
                .hCenter()
                .size(CGSize(width: side, height: 44))
        } else {
            emptyGlyph.pin
                .vCenter(-14)
                .hCenter()
                .size(CGSize(width: side, height: 44))
        }
        emptyLabel.pin
            .below(of: emptyGlyph)
            .horizontally()
            .marginTop(6)
            .sizeToFit(.width)
        guard !photos.isEmpty else {
            return side
        }
        let height = NewSpotPhotosLayout.height(for: photos.count, width: width)
        photosView.pin
            .top()
            .start()
            .width(width)
            .height(height)
        addButton.pin
            .top(side - 12 - Self.addSide)
            .end((width - side) / 2 + 12)
            .size(Self.addSide)
        return height
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Int, UUID> {
        let registration = UICollectionView.CellRegistration<NewSpotPhotoCell, UUID> { [weak self] cell, indexPath, id in
            guard let self, let photo = photos[id: id] else {
                return
            }
            cell.photoView.content = content(of: photo)
            cell.photoView.trailingInset = canAddMore ? Self.addSide + 8 : 0
            cell.onRemove = { [weak self] in self?.onRemovePhoto?(id) }
            cell.isVideo = photo.clipMilliseconds != nil
            cell.setArranging(isArranging, animated: false)
            cell.accessibilityLabel = indexPath.item == 0
                ? ContributeKitStrings.NewSpotCover.A11y.cover
                : ContributeKitStrings.NewSpotCover.A11y.photo(indexPath.item + 1)
            cell.accessibilityValue = [
                photo.clipMilliseconds.map(ClipBadgeView.accessibilityText(milliseconds:)),
                Self.problem(photo)?.text ?? Self.credit(photo),
            ].compactMap(\.self).joined(separator: ", ")
            cell.accessibilityHint = photo.added == nil ? nil : ContributeKitStrings.NewSpotCover.A11y.photoHint
            cell.accessibilityCustomActions = accessibilityActions(for: id)
        }
        return UICollectionViewDiffableDataSource(collectionView: photosView) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: id)
        }
    }

    private func content(of photo: NewSpotForm.Photo) -> NewSpotPhotoView.Content {
        NewSpotPhotoView.Content(
            image: thumbnails[photo.id],
            remote: photo.stored.map {
                NewSpotPhotoView.Content.Remote(key: $0.key, thumbhash: $0.thumbhash, scale: traitCollection.displayScale)
            },
            isPreparing: photo.added?.state == .preparing,
            problem: Self.problem(photo),
            credit: Self.credit(photo),
            clipMilliseconds: photo.clipMilliseconds,
        )
    }

    private func setArranging(_ arranging: Bool) {
        guard arranging != isArranging else {
            return
        }
        isArranging = arranging
        // Arranging, a photo lifts as soon as it's touched, as on the Home Screen.
        photosView.pressDuration = arranging ? 0.15 : 0.5
        for case let cell as NewSpotPhotoCell in photosView.visibleCells {
            cell.setArranging(arranging, animated: true)
        }
        UIView.animate(withDuration: 0.2) {
            self.addButton.alpha = arranging ? 0 : 1
        }
        onArrangingChange?()
    }

    /// Dragging has no VoiceOver equivalent of its own, so each photo can move a place either way.
    private func accessibilityActions(for id: UUID) -> [UIAccessibilityCustomAction] {
        guard let index = photos.index(id: id) else {
            return []
        }
        var actions = [UIAccessibilityCustomAction]()
        if index > 0 {
            actions.append(UIAccessibilityCustomAction(name: ContributeKitStrings.PhotoCredit.makeCover) { [weak self] _ in
                self?.onMovePhoto?(id, 0)
                return true
            })
            actions
                .append(UIAccessibilityCustomAction(name: ContributeKitStrings.NewSpotCover.A11y.moveEarlier) { [weak self] _ in
                    self?.onMovePhoto?(id, index - 1)
                    return true
                })
        }
        if index < photos.count - 1 {
            actions.append(UIAccessibilityCustomAction(name: ContributeKitStrings.NewSpotCover.A11y.moveLater) { [weak self] _ in
                self?.onMovePhoto?(id, index + 1)
                return true
            })
        }
        let removeTitle = PhotoCreditEditorView.removeTitle(isVideo: photos[index].clipMilliseconds != nil)
        actions.append(UIAccessibilityCustomAction(name: removeTitle) { [weak self] _ in
            self?.onRemovePhoto?(id)
            return true
        })
        return actions
    }

    private func decodeThumbnail(of id: UUID, from jpeg: Data) {
        decoding[id] = Task { [weak self] in
            let thumbnail = await Self.thumbnail(of: jpeg)
            guard !Task.isCancelled, let self else {
                return
            }
            decoding[id] = nil
            thumbnails[id] = thumbnail
            show(photos, canAddMore: canAddMore)
        }
    }

    @objc
    private func reduceMotionChanged() {
        for case let cell as NewSpotPhotoCell in photosView.visibleCells {
            cell.setArranging(isArranging, animated: false)
        }
    }

    /// Arranging ends with a tap beside the photos, as on the Home Screen.
    @objc
    private func backgroundTapped(_ tap: UITapGestureRecognizer) {
        let location = tap.location(in: photosView)
        if isArranging, photosView.indexPathForItem(at: location) == nil,
           !(photosView.hitTest(location, with: nil) is UIControl) {
            setArranging(false)
        }
    }
}

// MARK: UICollectionViewDelegate

extension NewSpotCoverView: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: false)
        if isArranging {
            setArranging(false)
        } else if let id = dataSource.itemIdentifier(for: indexPath), let cell = collectionView.cellForItem(at: indexPath) {
            onSelectPhoto?(id, cell)
        }
    }
}

// MARK: ReorderableCollectionViewDelegate

extension NewSpotCoverView: ReorderableCollectionViewDelegate {
    func collectionView(_: ReorderableCollectionView, liftedViewForItemAt indexPath: IndexPath) -> UIView? {
        guard let id = dataSource.itemIdentifier(for: indexPath), let photo = photos[id: id] else {
            return nil
        }
        let view = NewSpotPhotoView()
        view.content = content(of: photo)
        return view
    }

    func collectionView(_: ReorderableCollectionView, moveItemAt source: IndexPath, to destination: IndexPath) {
        var snapshot = dataSource.snapshot()
        let ids = snapshot.itemIdentifiers
        if destination.item > source.item {
            snapshot.moveItem(ids[source.item], afterItem: ids[destination.item])
        } else {
            snapshot.moveItem(ids[source.item], beforeItem: ids[destination.item])
        }
        dataSource.apply(snapshot, animatingDifferences: true)
    }

    func collectionView(_: ReorderableCollectionView, didLiftItemAt _: IndexPath) {
        setArranging(true)
    }

    func collectionView(_: ReorderableCollectionView, didEndReorderingItemAt indexPath: IndexPath) {
        guard let id = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        if photos.index(id: id) == indexPath.item {
            show(photos, canAddMore: canAddMore)
        } else {
            onMovePhoto?(id, indexPath.item)
        }
    }
}
