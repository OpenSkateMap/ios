import ComponentKit
import PeopleKit
import PhotoUploadKit
import PinLayout
import UIKit

// MARK: - EditProfileViewController

final class EditProfileViewController: UIViewController {

    // MARK: Properties

    private let model: EditProfileModel
    private let scrollView = UIScrollView().softEdges()
    private let form = FormStackView()
    private let avatarEditor = AvatarEditorView()
    private let nameRow = FieldRowView(title: nil, placeholder: ProfileKitStrings.EditProfile.Name.placeholder)
    private let usernameRow = FieldRowView(
        title: nil,
        placeholder: ProfileKitStrings.EditProfile.Username.placeholder,
        handle: "@",
    )
    private let usernameHint = Label()
    private let bioView = UITextView().softEdges()
    private let bioCounter = Label()
    private var shownAvatar: ProfileDraft.AvatarChoice?
    private var textFields = [UITextField]()
    private lazy var doneItem = UIBarButtonItem(
        systemItem: .done,
        primaryAction: UIAction { [weak self] _ in self?.save() },
    )
    private let savingItem = UIBarButtonItem.spinner()
    private var saving: Task<Void, Never>?
    private lazy var photoPicker = PhotoPicker(presenter: self) { [weak self] files in
        if let file = files.first {
            self?.useAvatar(file)
        }
    }

    // MARK: Lifecycle

    init(profile: PublicProfile) {
        model = EditProfileModel(profile: profile)
        super.init(nibName: nil, bundle: nil)
        title = ProfileKitStrings.EditProfile.title
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.cancel() },
        )
        doneItem.style = .prominent
        navigationItem.rightBarButtonItem = doneItem
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.addSubview(form)
        view.addSubview(scrollView)
        presentationController?.delegate = self

        avatarEditor.button.menu = UIMenu(children: [UIDeferredMenuElement.uncached { [weak self] completion in
            completion(self?.avatarActions() ?? [])
        }])

        configure(nameRow.textField, text: model.draft.name, contentType: .name) { $0.draft.name = $1 }
        nameRow.textField.accessibilityLabel = ProfileKitStrings.EditProfile.Name.title
        configure(usernameRow.textField, text: model.draft.username, contentType: nil, prefix: "@") {
            $0.draft.username = $1
        }
        usernameRow.textField.accessibilityLabel = ProfileKitStrings.EditProfile.Username.title
        usernameRow.textField.autocapitalizationType = .none
        usernameHint.font = .preferredFont(forTextStyle: .footnote)
        usernameHint.adjustsFontForContentSizeCategory = true
        usernameHint.numberOfLines = 0

        bioView.font = .preferredFont(forTextStyle: .body)
        bioView.adjustsFontForContentSizeCategory = true
        bioView.backgroundColor = .secondarySystemBackground
        bioView.layer.cornerRadius = 14
        bioView.layer.cornerCurve = .continuous
        bioView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        bioView.text = model.draft.bio
        bioView.delegate = self
        bioView.accessibilityLabel = ProfileKitStrings.EditProfile.Bio.title
        bioCounter.font = .preferredFont(forTextStyle: .footnote)
        bioCounter.adjustsFontForContentSizeCategory = true

        form.add(avatarEditor, spacingBefore: 0)
        form.add(Self.header(ProfileKitStrings.EditProfile.Name.title), spacingBefore: 24)
        form.add(nameRow, spacingBefore: 8)
        form.add(Self.header(ProfileKitStrings.EditProfile.Username.title), spacingBefore: 24)
        form.add(usernameRow, spacingBefore: 8)
        form.add(usernameHint, spacingBefore: 6)
        form.add(Self.header(ProfileKitStrings.EditProfile.Bio.title), spacingBefore: 24)
        form.add(bioView, height: 104, spacingBefore: 8)
        form.add(bioCounter, spacingBefore: 4)
        form.add(Self.header(ProfileKitStrings.EditProfile.Social.title), spacingBefore: 24)
        form.add(Self.hint(ProfileKitStrings.EditProfile.Social.hint), spacingBefore: 4)
        for network in HandleNetwork.allCases {
            let row = FieldRowView(
                title: network.title,
                icon: network.tile(side: 24, traitCollection: traitCollection),
                placeholder: network.placeholder,
                handle: network.prefix,
            )
            configure(
                row.textField,
                text: model.draft.handles[network] ?? "",
                contentType: network == .website ? .URL : nil,
                prefix: network.prefix,
            ) {
                $0.draft.handles[network] = $1
            }
            row.textField.accessibilityLabel = network.title
            row.textField.keyboardType = network == .website ? .URL : .asciiCapable
            row.textField.autocapitalizationType = .none
            form.add(row, spacingBefore: 8)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
        )
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.pin
            .all()
        let width = scrollView.bounds.width - view.layoutMargins.left - view.layoutMargins.right
        form.pin
            .top(16)
            .start(view.layoutMargins)
            .width(width)
            .sizeToFit(.width)
        scrollView.contentSize = CGSize(width: scrollView.bounds.width, height: form.frame.maxY + 32)
    }

    override func updateProperties() {
        super.updateProperties()

        doneItem.isEnabled = model.canSave
        navigationItem.showRightItem(model.isSaving ? savingItem : doneItem)
        navigationItem.leftBarButtonItem?.isEnabled = !model.isSaving
        for field in textFields {
            field.isEnabled = !model.isSaving
        }
        bioView.isEditable = !model.isSaving
        isModalInPresentation = model.hasChanges
        avatarEditor.setPreparing(model.isPreparingAvatar)
        avatarEditor.button.isEnabled = !model.isPreparingAvatar && !model.isSaving
        if model.draft.avatar != shownAvatar {
            shownAvatar = model.draft.avatar
            switch model.draft.avatar {
            case .unchanged:
                avatarEditor.avatar.show(name: model.original.name, avatar: model.original.avatar)

            case .removed:
                avatarEditor.avatar.show(name: model.original.name, image: nil)

            case .replaced:
                avatarEditor.avatar.show(name: model.original.name, image: model.avatarPreview)
            }
        }
        let problem = model.usernameProblem
        usernameHint.text = problem ?? ProfileKitStrings.EditProfile.Username.hint
        usernameHint.textColor = problem == nil ? .secondaryLabel : .systemRed
        bioCounter.text = ProfileKitStrings.EditProfile.Bio.counter(model.draft.bio.count, EditProfileModel.bioLimit)
        bioCounter.textAlignment = traitCollection.trailingTextAlignment
        bioCounter.textColor = model.draft.bio.count > EditProfileModel.bioLimit ? .systemRed : .secondaryLabel
        form.setNeedsLayout()
        view.setNeedsLayout()
    }

    // MARK: Overrides

    override func accessibilityPerformEscape() -> Bool {
        if navigationItem.leftBarButtonItem?.isEnabled == true {
            cancel()
        }
        return true
    }

    // MARK: Static Functions

    private static func header(_ text: String) -> Label {
        let label = Label()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.accessibilityTraits = .header
        return label
    }

    private static func hint(_ text: String) -> Label {
        let label = Label()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }

    // MARK: Functions

    private func configure(_ field: UITextField,
                           text: String,
                           contentType: UITextContentType?,
                           prefix: String = "",
                           onChange: @escaping (EditProfileModel, String) -> Void) {
        textFields.append(field)
        field.text = text
        field.textContentType = contentType
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.returnKeyType = .next
        field.addAction(UIAction { [weak self, weak field] _ in
            guard let self, let field else {
                return
            }
            if !prefix.isEmpty, let typed = field.text, typed.hasPrefix(prefix) {
                field.text = String(typed.dropFirst(prefix.count))
            }
            onChange(model, field.text ?? "")
        }, for: .editingChanged)
        field.addAction(UIAction { [weak field] _ in field?.resignFirstResponder() }, for: .editingDidEndOnExit)
    }

    private func avatarActions() -> [UIMenuElement] {
        var actions: [UIMenuElement] = [UIMenu(options: .displayInline, children: photoPicker.actions())]
        if model.hasAvatar {
            actions
                .append(UIAction(
                    title: ProfileKitStrings.EditProfile.Photo.remove,
                    image: UIImage(systemName: "trash"),
                    attributes: .destructive,
                ) { [weak self] _ in
                    self?.model.removeAvatar()
                })
        }
        return actions
    }

    private func useAvatar(_ data: Data?) {
        Task { [weak self] in
            do {
                guard let data else {
                    throw CocoaError(.fileReadUnknown)
                }
                try await self?.model.setAvatar(data)
            } catch {
                ToastView.showFailure(ProfileKitStrings.EditProfile.Photo.failed)
            }
        }
    }

    private func save() {
        view.endEditing(true)
        guard saving == nil, model.canSave else {
            return
        }
        saving = Task { [weak self, model] in
            defer { self?.saving = nil }
            do {
                guard try await model.save() != nil else {
                    self?.usernameRow.textField.becomeFirstResponder()
                    return
                }
                self?.dismiss(animated: true)
            } catch {
                ToastView.showFailure(ProfileKitStrings.EditProfile.Save.failed, subtitle: PeopleAPIError.message(for: error))
            }
        }
    }

    private func cancel() {
        guard model.hasChanges else {
            dismiss(animated: true)
            return
        }
        confirmDiscard()
    }

    private func confirmDiscard() {
        let alert = UIAlertController(
            title: nil,
            message: ProfileKitStrings.EditProfile.Discard.message,
            preferredStyle: .actionSheet,
        )
        alert.addAction(UIAlertAction(
            title: ProfileKitStrings.EditProfile.Discard.confirm,
            style: .destructive,
        ) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        alert.addAction(UIAlertAction(title: ProfileKitStrings.EditProfile.Discard.keep, style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
        present(alert, animated: true)
    }

    @objc
    private func keyboardWillChangeFrame(_ notification: Notification) {
        guard let screen = view.window?.screen,
              let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        let overlap = max(
            view.bounds.maxY - view.convert(frame, from: screen.coordinateSpace).minY - view.safeAreaInsets.bottom,
            0,
        )
        scrollView.contentInset.bottom = overlap
        scrollView.verticalScrollIndicatorInsets.bottom = overlap
    }
}

// MARK: UITextViewDelegate

extension EditProfileViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        model.draft.bio = textView.text
    }
}

// MARK: UIAdaptivePresentationControllerDelegate

extension EditProfileViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidAttemptToDismiss(_: UIPresentationController) {
        confirmDiscard()
    }
}
