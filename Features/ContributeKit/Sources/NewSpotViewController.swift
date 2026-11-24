import ComponentKit
import ContributionsKit
import FactoryKit
import IdentifiedCollections
import ImageKit
import LocationKit
import PinLayout
import ReviewKit
import SpotModelKit
import UIKit

// MARK: - NewSpotViewController

final class NewSpotViewController: UIViewController {

    // MARK: Computed Properties

    private var nameField: UITextField {
        namePill.field
    }

    private var tint: UIColor? {
        model.form.coverThumbhash.flatMap { ThumbHashRenderer.averageColor(base64: $0) }
    }

    private var trailingItem: UIBarButtonItem {
        if cover.isArranging {
            doneArrangingItem
        } else if model.isApproving {
            approvingItem
        } else {
            submitItem
        }
    }

    // MARK: Properties

    var onClose: (() -> Void)?
    var onSubmitted: ((_ id: String, _ title: String, _ location: NewSpotForm.Location, _ tint: UIColor?, _ collection: String?)
        -> Void)?
    var onReviewEnded: (() -> Void)?

    @Injected(\.geocodingManager) private var geocoding

    private let model: NewSpotModel
    private let background = TintedBackgroundView()
    private let scrollView = UIScrollView().softEdges()
    private let form = FormStackView()
    private let cover = NewSpotCoverView()
    private let namePill = NamePillView()
    private let locationRow = FormRowButton(
        glyph: UIImage(systemName: "mappin.and.ellipse"),
        title: ContributeKitStrings.NewSpot.Location.choose,
    )
    private let locationMap = SpotLocationMapView()
    private let nearbyLabel = InsetLabel()
    private let descriptionRow = FormRowButton(
        // It shows which way text runs, so it mirrors right to left.
        glyph: UIImage(systemName: "text.alignleft")?.imageFlippedForRightToLeftLayoutDirection(),
        title: ContributeKitStrings.NewSpot.Description.row,
        accessory: .none,
    )
    private let kindRow = FormRowButton(
        glyph: UIImage(systemName: "square.grid.2x2"),
        title: ContributeKitStrings.NewSpot.Kind.title,
        accessory: .upDown,
    )
    private let conditionRow = FormRowButton(
        glyph: UIImage(systemName: "checkmark.seal"),
        title: ContributeKitStrings.NewSpot.Condition.title,
        accessory: .upDown,
    )
    private let obstaclesRow = FormRowButton(
        glyph: UIImage(systemName: "square.stack.3d.up"),
        title: ContributeKitStrings.NewSpot.Obstacles.title,
    )
    private let noteRow = FormRowButton(
        glyph: UIImage(systemName: "text.bubble"),
        title: ContributeKitStrings.NewSpot.Note.row,
        accessory: .none,
    )
    private let destinationRow = FormRowButton(
        glyph: UIImage(systemName: "globe"),
        title: ContributeKitStrings.NewSpot.Visibility.title,
        accessory: .upDown,
    )
    private lazy var destinationCard = FormCardView(rows: [destinationRow])
    private let destinationHint = FormText.hint("")
    private let curatorHeader = FormText.header(ContributeKitStrings.NewSpot.Curator.header)
    private lazy var curatorCard = FormCardView(rows: [noteRow])
    private let curatorHint = FormText.hint(ContributeKitStrings.NewSpot.Curator.hint)
    private let submitItem = UIBarButtonItem(image: UIImage(systemName: "checkmark"), style: .prominent, target: nil, action: nil)
    private let approvingItem = UIBarButtonItem.spinner()
    private var renaming: Task<Void, Never>?
    private weak var creditReview: PhotoCreditReview?
    private lazy var doneArrangingItem = UIBarButtonItem(
        systemItem: .done,
        primaryAction: UIAction { [weak self] _ in self?.cover.endArranging() },
    )
    private lazy var videoIntake = NewSpotVideoIntake(model: model, presenter: self) { [weak self] in self?.tint }
    private lazy var photoPicker = PhotoPicker(
        presenter: self,
        limit: { [weak self] in self?.model.form.photosLeft ?? 0 },
        allowsVideos: true,
        onStart: { [weak self] kinds, source in self?.beginPick(kinds, from: source) ?? { _, _ in } },
    )

    // MARK: Lifecycle

    init(model: NewSpotModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        title = model.copy.title
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        renaming?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItems()
        setupViews()
        setupActions()
        setupForm()
        setupForMode()
        nameReviewedLocation()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        background.pin
            .all()
        scrollView.pin
            .all()
        let inset: CGFloat = 16
        form.pin
            .top(12)
            .horizontally(view.safeAreaInsets)
            .marginHorizontal(inset)
            .sizeToFit(.width)
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: form.frame.maxY + 32)
    }

    override func updateProperties() {
        super.updateProperties()

        let form = model.form
        background.tint = tint
        cover.show(form.photos, canAddMore: form.canAddPhotos)
        creditReview?.refresh()
        if !nameField.isEditing, nameField.text != form.title {
            nameField.text = form.title
        }
        showLocation(form.location)
        showNearby(model.nearby)
        let about = form.trimmedAbout
        descriptionRow.title = about.isEmpty ? ContributeKitStrings.NewSpot.Description.row : about
        descriptionRow.isPlaceholder = about.isEmpty
        kindRow.value = form.kind?.title ?? ContributeKitStrings.NewSpot.Kind.choose
        kindRow.menu = .kinds(selected: form.kind) { [weak self] kind in self?.model.edit { $0.kind = kind } }
        conditionRow.value = form.condition.title
        conditionRow.menu = .conditions(selected: form.condition) { [weak self] condition in
            self?.model.edit { $0.condition = condition }
        }
        obstaclesRow.value = Self.obstaclesSummary(form.orderedObstacles)
        let note = form.trimmedNote
        noteRow.title = note.isEmpty ? ContributeKitStrings.NewSpot.Note.row : note
        noteRow.isPlaceholder = note.isEmpty
        let isPrivate = form.collectionID != nil
        destinationRow.glyph = UIImage(systemName: isPrivate ? "lock" : "globe")
        destinationRow.value = model.destinationName ?? ContributeKitStrings.NewSpot.Visibility.publicMap
        destinationRow.menu = destinationMenu(selected: form.collectionID)
        destinationRow.isBusy = model.isCreatingCollection
        destinationHint.text =
            switch (isPrivate, model.goesToCurators) {
            case (true, _): ContributeKitStrings.NewSpot.Visibility.privateHint
            case (false, true): ContributeKitStrings.NewSpot.Visibility.publicHint
            case (false, false): ContributeKitStrings.NewSpot.Visibility.adminHint
            }
        for view in [curatorHeader, curatorCard, curatorHint] as [UIView] {
            view.isHidden = !model.goesToCurators
        }
        submitItem.isEnabled = model.canSubmit
        submitItem.accessibilityHint = Self.missingHint(form.missing)
        if navigationItem.rightBarButtonItem !== trailingItem {
            navigationItem.rightBarButtonItem = trailingItem
        }
        navigationItem.leftBarButtonItem?.isEnabled = !model.isApproving
        view.isUserInteractionEnabled = !model.isApproving
        view.setNeedsLayout()
    }

    // MARK: Overrides

    override func accessibilityPerformEscape() -> Bool {
        onClose?()
        return true
    }

    // MARK: Static Functions

    static func missingHint(_ missing: [NewSpotForm.Requirement]) -> String? {
        guard !missing.isEmpty else {
            return nil
        }
        let parts = missing.compactMap { requirement -> String? in
            switch requirement {
            case .photosReady: nil
            case .photoCredits: ContributeKitStrings.NewSpot.Missing.photoCredits
            case .name: ContributeKitStrings.NewSpot.Missing.name
            case .location: ContributeKitStrings.NewSpot.Missing.location
            case .kind: ContributeKitStrings.NewSpot.Missing.kind
            case .change: nil
            }
        }
        if missing == [.change] {
            return ContributeKitStrings.NewSpot.Missing.change
        }
        let sentences = [
            parts.isEmpty ? nil : ContributeKitStrings.NewSpot.Missing.submit(ListFormatter.localizedString(byJoining: parts)),
            missing.contains(.photosReady) ? ContributeKitStrings.NewSpot.Missing.photosReady : nil,
        ]
        return sentences.compactMap(\.self).joined(separator: "\n")
    }

    /// The first two and how many more ("Stairs, Hubbas +4"), so the row never cuts a name off.
    private static func obstaclesSummary(_ obstacles: [String]) -> String {
        guard !obstacles.isEmpty else {
            return ContributeKitStrings.NewSpot.Obstacles.empty
        }
        let shown = obstacles.prefix(2).map(SpotObstacle.title(of:)).joined(separator: ", ")
        return obstacles.count > 2 ? ContributeKitStrings.NewSpot.Obstacles.more(shown, obstacles.count - 2) : shown
    }

    // MARK: Functions

    func scrollToTop() {
        scrollView.setContentOffset(CGPoint(x: 0, y: -scrollView.adjustedContentInset.top), animated: false)
    }

    private func setupNavigationItems() {
        navigationItem.largeTitleDisplayMode = .never
        let close = UIBarButtonItem(systemItem: .close, primaryAction: UIAction { [weak self] _ in self?.onClose?() })
        close.accessibilityLabel = ContributeKitStrings.NewSpot.A11y.close
        navigationItem.leftBarButtonItem = close
        submitItem.primaryAction = UIAction(image: UIImage(systemName: "checkmark")) { [weak self] _ in self?.confirmSubmit() }
        submitItem.accessibilityLabel = model.copy.submitLabel
        submitItem.tintColor = .label
        approvingItem.accessibilityLabel = ContributeKitStrings.ReviewEdit.approving
        navigationItem.rightBarButtonItem = submitItem
    }

    private func setupViews() {
        view.backgroundColor = .systemBackground
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        cover.addPhotosMenu = UIMenu(children: photoPicker.actions())
        nameField.placeholder = ContributeKitStrings.NewSpot.namePlaceholder
        nameField.autocorrectionType = .no
        nameField.returnKeyType = .done
        nameField.accessibilityLabel = ContributeKitStrings.NewSpot.A11y.name
        locationRow.isPlaceholder = true
        locationMap.showsPin = false
        locationRow.attachedView = locationMap
        nearbyLabel.numberOfLines = 0
        nearbyLabel.insets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        nearbyLabel.isHidden = true
        descriptionRow.isPlaceholder = true
        descriptionRow.titleLines = 2
        kindRow.showsMenuAsPrimaryAction = true
        conditionRow.showsMenuAsPrimaryAction = true
        noteRow.isPlaceholder = true
        noteRow.titleLines = 2
        destinationRow.showsMenuAsPrimaryAction = true
    }

    private func setupActions() {
        cover.onSelectPhoto = { [weak self] id, cell in self?.editCredit(of: id, from: cell) }
        cover.onMovePhoto = { [weak self] id, index in self?.model.edit { $0.movePhoto(id, to: index) } }
        cover.onRemovePhoto = { [weak self] in self?.model.removePhoto($0) }
        cover.onArrangingChange = { [weak self] in
            guard let self else {
                return
            }
            navigationItem.setRightBarButton(trailingItem, animated: true)
        }
        nameField.addAction(UIAction { [weak self] _ in self?.nameChanged() }, for: .editingChanged)
        nameField.addAction(UIAction { [weak self] _ in self?.nameField.resignFirstResponder() }, for: .editingDidEndOnExit)
        locationRow.addAction(UIAction { [weak self] _ in self?.chooseLocation() }, for: .primaryActionTriggered)
        descriptionRow.addAction(UIAction { [weak self] _ in self?.editDescription() }, for: .primaryActionTriggered)
        obstaclesRow.addAction(UIAction { [weak self] _ in self?.editObstacles() }, for: .primaryActionTriggered)
        noteRow.addAction(UIAction { [weak self] _ in self?.editNote() }, for: .primaryActionTriggered)
    }

    private func setupForm() {
        if case .review(let card) = model.form.mode, card.isEdit {
            form.add(FormText.hint(ContributeKitStrings.ReviewEdit.editHint), spacingBefore: 0)
        }
        form.add(cover, spacingBefore: 16)
        form.add(namePill, spacingBefore: 24)
        form.add(FormCardView(rows: [locationRow, nearbyLabel]), spacingBefore: 12)
        form.add(FormCardView(rows: [descriptionRow]), spacingBefore: 12)
        form.add(destinationCard, spacingBefore: 12)
        form.add(destinationHint, spacingBefore: 8)
        form.add(FormText.header(ContributeKitStrings.NewSpot.spotHeader), spacingBefore: 28)
        form.add(FormCardView(rows: [kindRow, conditionRow, obstaclesRow]), spacingBefore: 10)
        form.add(curatorHeader, spacingBefore: 28)
        form.add(curatorCard, spacingBefore: 10)
        form.add(curatorHint, spacingBefore: 8)
        scrollView.addSubview(form)
        view.addSubview(background)
        view.addSubview(scrollView)
    }

    private func setupForMode() {
        destinationCard.isHidden = model.form.mode != .new
        destinationHint.isHidden = model.form.mode != .new
        namePill.isEnabled = model.form.isEditable(.title)
        locationRow.isEnabled = model.form.isEditable(.location)
        descriptionRow.isEnabled = model.form.isEditable(.description)
        kindRow.isEnabled = model.form.isEditable(.spotKind)
        conditionRow.isEnabled = model.form.isEditable(.condition)
        obstaclesRow.isEnabled = model.form.isEditable(.obstacles)
    }

    /// A card has a pin but no address; until one comes back, the row reads as the spot's name.
    private func nameReviewedLocation() {
        guard case .review = model.form.mode, let location = model.form.location else {
            return
        }
        lookUpName(of: location, fallback: location.name) { [weak self] named in
            self?.model.edit { $0.location = named }
        }
    }

    /// The name stays unless the address comes back while the pin is still `location`.
    private func lookUpName(of location: NewSpotForm.Location,
                            fallback: String,
                            apply: @escaping (NewSpotForm.Location) -> Void) {
        renaming?.cancel()
        renaming = Task { [geocoding, weak self] in
            let address = await geocoding.address(location.coordinate)
            guard !Task.isCancelled, let self, model.form.location == location else {
                return
            }
            apply(LocationSearchViewController.place(at: location.coordinate, address: address, fallback: fallback))
        }
    }

    private func nameChanged() {
        let text = nameField.text ?? ""
        model.edit { $0.title = text }
    }

    private func showLocation(_ location: NewSpotForm.Location?) {
        locationMap.isHidden = location == nil
        guard let location else {
            locationRow.title = ContributeKitStrings.NewSpot.Location.choose
            locationRow.subtitle = nil
            locationRow.isPlaceholder = true
            locationRow.glyph = UIImage(systemName: "mappin.and.ellipse")
            locationRow.accessory = .chevron
            locationRow.showsMenuAsPrimaryAction = false
            locationRow.menu = nil
            return
        }
        locationRow.title = location.name
        locationRow.subtitle = location.subtitle
        locationRow.isPlaceholder = false
        locationRow.accessory = .more
        locationRow.menu = UIMenu(children: [
            UIAction(
                title: ContributeKitStrings.NewSpot.Location.change,
                image: UIImage(systemName: "magnifyingglass"),
            ) { [weak self] _ in
                self?.chooseLocation()
            },
            UIAction(
                title: ContributeKitStrings.NewSpot.Location.adjustPin,
                image: UIImage(systemName: "mappin"),
            ) { [weak self] _ in
                self?.adjustPin()
            },
        ])
        locationRow.showsMenuAsPrimaryAction = true
        locationMap.show(location.coordinate)
    }

    private func showNearby(_ nearby: [NearbySpot]) {
        nearbyLabel.isHidden = nearby.isEmpty
        guard !nearby.isEmpty else {
            return
        }
        let text = NSMutableAttributedString()
        if let warning = UIImage(systemName: "exclamationmark.triangle.fill")?.withTintColor(
            .systemOrange,
            renderingMode: .alwaysOriginal,
        ) {
            text.append(NSAttributedString(attachment: NSTextAttachment(image: warning)))
            text.append(NSAttributedString(string: " "))
        }
        let spots = nearby.prefix(3)
            .map { ContributeKitStrings.NewSpot.Nearby.spot($0.title, $0.distanceText) }
            .joined(separator: ", ")
        text.append(NSAttributedString(string: ContributeKitStrings.NewSpot.Nearby.list(spots)))
        text.addAttributes(
            [.font: UIFont.preferredFont(forTextStyle: .subheadline), .foregroundColor: UIColor.label],
            range: NSRange(location: 0, length: text.length),
        )
        nearbyLabel.attributedText = text
        nearbyLabel.accessibilityLabel = ContributeKitStrings.NewSpot.A11y.nearby(spots)
    }

    private func destinationMenu(selected: String?) -> UIMenu {
        let publicMap = UIAction(
            title: ContributeKitStrings.NewSpot.Visibility.publicMap,
            image: UIImage(systemName: "globe"),
            state: selected == nil ? .on : .off,
        ) { [weak self] _ in
            self?.model.edit { $0.collectionID = nil }
        }
        let collections = model.privateCollections.map { collection in
            UIAction(title: collection.name, image: UIImage(systemName: "lock"), state: collection.id == selected ? .on : .off) {
                [weak self] _ in
                self?.model.edit { $0.collectionID = collection.id }
            }
        }
        let create = UIAction(
            title: ContributeKitStrings.NewSpot.NewCollection.title,
            image: UIImage(systemName: "plus"),
        ) { [weak self] _ in
            self?.createPrivateCollection()
        }
        return UIMenu(children: [
            publicMap,
            UIMenu(
                title: ContributeKitStrings.NewSpot.Visibility.privateCollections,
                options: .displayInline,
                children: collections + [create],
            ),
        ])
    }

    private func createPrivateCollection() {
        let alert = UIAlertController(
            title: ContributeKitStrings.NewSpot.NewCollection.title,
            message: ContributeKitStrings.NewSpot.NewCollection.message,
            preferredStyle: .alert,
        )
        alert.addTextField { field in
            field.placeholder = ContributeKitStrings.NewSpot.NewCollection.placeholder
            field.autocapitalizationType = .words
        }
        alert.addAction(UIAlertAction(title: ContributeKitStrings.Alert.cancel, style: .cancel))
        alert.addAction(UIAlertAction(
            title: ContributeKitStrings.NewSpot.NewCollection.create,
            style: .default,
        ) { [weak self, weak alert] _ in
            let name = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard let self, !name.isEmpty else {
                return
            }
            Task {
                do {
                    try await self.model.createPrivateCollection(named: name)
                } catch {
                    ToastView.showFailure(
                        ContributeKitStrings.NewSpot.NewCollection.failedTitle,
                        subtitle: ContributeKitStrings.NewSpot.NewCollection.failedMessage,
                    )
                }
            }
        })
        present(alert, animated: true)
    }

    /// Each pick shows as a preparing tile at once; its videos go through the trimmer and the cover frame first, then
    /// who took each photo is asked for the whole pick, except for the camera's, which is the person's own.
    private func beginPick(_ kinds: [PhotoPicker.Kind], from source: PhotoPicker.Source) -> PhotoPicker.Receiver {
        let ids = model.beginPhotos(kinds.count)
        let videos = zip(ids, kinds).filter { $0.1 == .video }.map(\.0)
        videoIntake.begin(videos) { [weak self] in
            guard let self, source != .camera else {
                return
            }
            let kept = ids.filter { self.model.form.photos[id: $0] != nil }
            if !kept.isEmpty {
                creditReview = PhotoCreditReview.present(for: kept, model: model, tint: tint, from: self)
            }
        }
        return { [weak self] index, pick in
            guard let self, index < ids.count else {
                if case .video(let file) = pick {
                    try? FileManager.default.removeItem(at: file)
                }
                return
            }
            switch (kinds[index], pick) {
            case (_, .photo(let data)): model.fillPhoto(ids[index], with: data)
            case (_, .video(let file)): videoIntake.receive(file, for: ids[index])
            case (.video, nil): videoIntake.receive(nil, for: ids[index])
            case (.photo, nil): model.fillPhoto(ids[index], with: nil)
            }
        }
    }

    private func editCredit(of id: UUID, from cell: UIView) {
        guard let index = model.form.photos.index(id: id) else {
            return
        }
        guard case .new(let added) = model.form.photos[index].source else {
            showStoredPhotoActions(id, isCover: index == 0, from: cell)
            return
        }
        let editor = PhotoCreditEditorView(credit: added.credit, for: .photo(isCover: index == 0))
        let sheet = OptionSheetViewController(
            title: ContributeKitStrings.PhotoCredit.title,
            message: ContributeKitStrings.PhotoCredit.message,
            content: editor,
            tint: tint,
        ) { [weak self, editor] in
            let credit = editor.draft
            self?.model.edit { $0.updateAddedPhoto(id) { $0.credit = credit } }
        }
        editor.onChange = { [weak sheet, editor] in
            sheet?.isConfirmEnabled = editor.draft.isComplete
            sheet?.contentDidChange()
        }
        editor.onMakeCover = { [weak self, weak sheet] in
            self?.model.edit { $0.makeCover(id) }
            sheet?.dismiss(animated: true)
        }
        editor.onRemove = { [weak self, weak sheet] in
            self?.model.removePhoto(id)
            sheet?.dismiss(animated: true)
        }
        sheet.isConfirmEnabled = editor.draft.isComplete
        present(sheet, animated: true)
    }

    private func chooseLocation() {
        let search = LocationSearchViewController(
            near: model.form.location?.coordinate,
            query: model.form.location?.name,
        ) { [weak self] choice in
            switch choice {
            case .place(let location): self?.model.setLocation(location)
            case .dropPin: self?.dropPin()
            }
        }
        present(search, animated: true)
    }

    private func dropPin() {
        presentPinPlacement(start: nil) { [weak self] coordinate in
            self?.placePin(at: coordinate, keepingName: nil)
        }
    }

    private func adjustPin() {
        guard let location = model.form.location else {
            return
        }
        presentPinPlacement(start: location.coordinate) { [weak self] coordinate in
            self?.placePin(at: coordinate, keepingName: location)
        }
    }

    private func presentPinPlacement(start: CLLocationCoordinate2D?, onDone: @escaping (CLLocationCoordinate2D) -> Void) {
        let navigation = UINavigationController(rootViewController: AdjustPinViewController(start: start, onDone: onDone))
        navigation.modalPresentationStyle = .fullScreen
        present(navigation, animated: true)
    }

    private func placePin(at coordinate: CLLocationCoordinate2D, keepingName named: NewSpotForm.Location?) {
        if let named {
            model.setLocation(NewSpotForm.Location(coordinate: coordinate, name: named.name, subtitle: named.subtitle))
            return
        }
        let dropped = NewSpotForm.Location(coordinate: coordinate, name: ContributeKitStrings.NewSpot.Location.droppedPin)
        model.setLocation(dropped)
        lookUpName(of: dropped, fallback: ContributeKitStrings.NewSpot.Location.droppedPin) { [weak self] named in
            self?.model.setLocation(named)
        }
    }

    private func editDescription() {
        editText(
            \.about,
            title: ContributeKitStrings.NewSpot.Description.title,
            message: ContributeKitStrings.NewSpot.Description.message,
            placeholder: ContributeKitStrings.NewSpot.Description.placeholder,
            limit: 2000,
        )
    }

    private func editNote() {
        editText(
            \.note,
            title: ContributeKitStrings.NewSpot.Note.title,
            message: ContributeKitStrings.NewSpot.Note.message,
            placeholder: ContributeKitStrings.NewSpot.Note.placeholder,
            limit: 500,
        )
    }

    private func editText(_ field: WritableKeyPath<NewSpotForm, String>,
                          title: String,
                          message: String,
                          placeholder: String,
                          limit: Int) {
        let editor = SheetTextEditorView(text: model.form[keyPath: field], placeholder: placeholder, limit: limit)
        let sheet = OptionSheetViewController(title: title, message: message, content: editor, tint: tint) { [
            weak self,
            editor,
        ] in
            let text = editor.text
            self?.model.edit { $0[keyPath: field] = text }
        }
        present(sheet, animated: true) { _ = editor.becomeFirstResponder() }
    }

    private func editObstacles() {
        let editor = ObstaclesEditorView(selection: model.form.obstacles)
        let sheet = OptionSheetViewController(
            title: ContributeKitStrings.NewSpot.Obstacles.title,
            message: ContributeKitStrings.NewSpot.Obstacles.message,
            content: editor,
            tint: tint,
        ) { [weak self, editor] in
            let selection = editor.selection
            self?.model.edit { $0.obstacles = selection }
        }
        present(sheet, animated: true)
    }

    /// A stored photo, the spot's or the card's: its credit is read-only, so only its place can change.
    private func showStoredPhotoActions(_ id: UUID, isCover: Bool, from cell: UIView) {
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        if !isCover {
            sheet.addAction(UIAlertAction(title: ContributeKitStrings.PhotoCredit.makeCover, style: .default) { [weak self] _ in
                self?.model.edit { $0.makeCover(id) }
            })
        }
        sheet.addAction(UIAlertAction(title: ContributeKitStrings.PhotoCredit.remove, style: .destructive) { [weak self] _ in
            self?.model.removePhoto(id)
        })
        sheet.addAction(UIAlertAction(title: ContributeKitStrings.Alert.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceView = cell
        present(sheet, animated: true)
    }

    private func confirmSubmit() {
        guard model.form.mode == .new, model.form.photos.isEmpty else {
            submit()
            return
        }
        nameField.resignFirstResponder()
        let sheet = UIAlertController(
            title: nil,
            message: ContributeKitStrings.NewSpot.NoPhoto.message,
            preferredStyle: .actionSheet,
        )
        sheet.addAction(UIAlertAction(title: ContributeKitStrings.NewSpot.NoPhoto.submit, style: .default) { [weak self] _ in
            self?.submit()
        })
        sheet.addAction(UIAlertAction(title: ContributeKitStrings.NewSpot.Discard.keepEditing, style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = submitItem
        present(sheet, animated: true)
    }

    private func submit() {
        guard let location = model.form.location else {
            return
        }
        nameField.resignFirstResponder()
        let title = model.form.trimmedTitle
        let tint = tint
        let collection = model.destinationName
        Task { [weak self] in
            guard let self else {
                return
            }
            switch await model.submit() {
            case .saved(let id):
                UINotificationFeedbackGenerator(view: view).notificationOccurred(.success)
                onSubmitted?(id, title, location, tint, collection)

            case .approved:
                UINotificationFeedbackGenerator(view: view).notificationOccurred(.success)
                onReviewEnded?()

            case .cardChanged:
                onReviewEnded?()

            case .busy:
                break

            case .failed:
                if let title = model.copy.saveFailedTitle {
                    ToastView.showFailure(title, subtitle: ContributeKitStrings.NewSpot.SaveFailed.message)
                }
            }
        }
    }
}
