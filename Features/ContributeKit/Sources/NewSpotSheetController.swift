import ComponentKit
import FactoryKit
import ReviewKit
public import SpotModelKit
public import UIKit

// MARK: - NewSpotSheetController

public final class NewSpotSheetController: UINavigationController {

    // MARK: Computed Properties

    private var needsDiscardConfirmation: Bool {
        !hasSubmitted && model.form.hasChanges
    }

    // MARK: Properties

    private let model: NewSpotModel
    private let form: NewSpotViewController
    private var hasSubmitted = false

    // MARK: Lifecycle

    /// `libraryPhotoIDs`: photos from the person's library the edit starts with, by PhotoKit local identifier.
    public convenience init(editing spot: SpotEditTarget? = nil, libraryPhotoIDs: [String] = []) {
        self.init(model: NewSpotModel(editing: spot, libraryPhotoIDs: libraryPhotoIDs))
    }

    /// Edit Before Approving: the ✓ approves the card with the curator's changes.
    convenience init(reviewing card: ReviewCard) {
        self.init(model: NewSpotModel(reviewing: card))
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private init(model: NewSpotModel) {
        self.model = model
        let form = NewSpotViewController(model: model)
        self.form = form
        super.init(rootViewController: form)
        setupPresentation()
        setupFormCallbacks()
    }

    // MARK: Functions

    private func setupPresentation() {
        modalPresentationStyle = .pageSheet
        sheetPresentationController?.detents = [.large()]
        sheetPresentationController?.prefersGrabberVisible = true
        presentationController?.delegate = self
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        navigationBar.standardAppearance = appearance
        navigationBar.scrollEdgeAppearance = appearance
    }

    private func setupFormCallbacks() {
        form.onClose = { [unowned self] in close() }
        form.onSubmitted = { [unowned self] id, title, location, tint, collection in
            showSubmitted(id: id, title: title, location: location, tint: tint, collection: collection)
        }
        form.onReviewEnded = { [weak self] in
            self?.hasSubmitted = true
            self?.dismiss(animated: true)
        }
    }

    private func close() {
        guard !model.isApproving else {
            return
        }
        if needsDiscardConfirmation {
            confirmDiscard()
        } else {
            dismiss(animated: true)
        }
    }

    private func confirmDiscard() {
        let copy = model.copy
        let sheet = UIAlertController(title: nil, message: copy.discardMessage, preferredStyle: .actionSheet)
        sheet
            .addAction(UIAlertAction(title: copy.discardConfirm, style: .destructive) { [weak self] _ in
                self?.dismiss(animated: true)
            })
        sheet.addAction(UIAlertAction(title: ContributeKitStrings.NewSpot.Discard.keepEditing, style: .cancel))
        sheet.popoverPresentationController?.barButtonItem = viewControllers.first?.navigationItem.leftBarButtonItem
        topViewController?.present(sheet, animated: true)
    }

    private func showSubmitted(id: String, title: String, location: NewSpotForm.Location, tint: UIColor?, collection: String?) {
        hasSubmitted = true
        let submitted = SpotSubmittedViewController(
            model: SpotSubmittedModel(
                id: id,
                title: title,
                location: location,
                isEdit: model.isEditing,
                isReviewed: model.goesToCurators,
                collection: collection,
            ),
            tint: tint,
            onViewInContribute: { [unowned self] in viewInContribute() },
            onAddAnother: model.isEditing ? nil : { [unowned self] in addAnother() },
        )
        pushViewController(submitted, animated: true)
    }

    private func viewInContribute() {
        let openContribute = Container.shared.contributeTabOpener()
        dismiss(animated: true) { openContribute?() }
    }

    private func addAnother() {
        model.reset()
        hasSubmitted = false
        form.scrollToTop()
        popToRootViewController(animated: true)
    }
}

// MARK: UIAdaptivePresentationControllerDelegate

extension NewSpotSheetController: UIAdaptivePresentationControllerDelegate {
    public func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        !needsDiscardConfirmation && !model.isApproving
    }

    public func presentationControllerDidAttemptToDismiss(_: UIPresentationController) {
        close()
    }
}
