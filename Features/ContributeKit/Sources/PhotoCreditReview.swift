import ComponentKit
import Foundation
import IdentifiedCollections
import PhotoUploadKit
import UIKit

/// Going through a pick's photos one at a time to say who took each: the photo, the choice, and
/// Previous / Next. Every photo has its own answer, kept as the person moves on and shown again on coming back; none
/// starts from another's. Lives as long as its sheet.
@MainActor
final class PhotoCreditReview {

    // MARK: Properties

    private var ids: [UUID]
    private let model: NewSpotModel
    private let step = PhotoCreditStepView()
    private weak var sheet: OptionSheetViewController?
    private var index = 0
    /// Whether the fields for someone else's photo were showing: the sheet resizes only when that changes.
    private var showsSomeoneElse = false
    private var images = [UUID: UIImage]()
    private var decoding = [UUID: Task<Void, Never>]()

    // MARK: Lifecycle

    isolated deinit {
        for task in decoding.values {
            task.cancel()
        }
    }

    private init(ids: [UUID], model: NewSpotModel) {
        self.ids = ids
        self.model = model
    }

    // MARK: Static Functions

    /// Presents the sheet; the review returned refreshes it as the photos finish preparing.
    static func present(for ids: [UUID],
                        model: NewSpotModel,
                        tint: UIColor?,
                        from presenter: UIViewController) -> PhotoCreditReview {
        let review = PhotoCreditReview(ids: ids, model: model)
        let sheet = OptionSheetViewController(
            title: ContributeKitStrings.PhotoCredit.title,
            message: ContributeKitStrings.PhotoCredit.message,
            content: review.step,
            tint: tint,
            confirmTitle: ContributeKitStrings.PhotoCredit.Review.next,
        ) {
            review.next()
        }
        sheet.closesOnConfirm = false
        sheet.secondaryAction = UIAction(title: ContributeKitStrings.PhotoCredit.Review.previous) { [weak review] _ in
            review?.previous()
        }
        review.sheet = sheet
        review.step.onChange = { [weak review] in review?.creditChanged() }
        review.decodeImages()
        review.showStep()
        presenter.present(sheet, animated: true)
        return review
    }

    @concurrent
    private nonisolated static func image(from jpeg: Data) async -> UIImage? {
        await UIImage(data: jpeg)?.byPreparingThumbnail(ofSize: CGSize(width: 1200, height: 1200))
    }

    // MARK: Functions

    /// The photos changed in the form: some may have finished preparing, and a clip that couldn't be made is gone.
    func refresh() {
        guard let sheet, sheet.presentingViewController != nil else {
            return
        }
        let kept = ids.filter { photo($0) != nil }
        if kept != ids {
            guard !kept.isEmpty else {
                sheet.dismiss(animated: true)
                return
            }
            let shown = ids[index]
            ids = kept
            if let place = kept.firstIndex(of: shown) {
                index = place
                showPosition(credit: step.editor.draft)
            } else {
                index = min(index, kept.count - 1)
                showStep()
            }
        }
        decodeImages()
        showImage()
    }

    private func photo(_ id: UUID) -> NewSpotForm.Photo.Added? {
        model.form.photos[id: id]?.added
    }

    private func showStep() {
        showPosition(credit: photo(ids[index])?.credit ?? NewSpotForm.Credit())
        showImage()
    }

    private func showPosition(credit: NewSpotForm.Credit) {
        step.show(page: index + 1, of: ids.count, credit: credit)
        sheet?.setConfirmTitle(
            index == ids.count - 1 ? ContributeKitStrings.PhotoCredit.Review.done : ContributeKitStrings.PhotoCredit.Review.next
        )
        sheet?.isSecondaryEnabled = index > 0
        creditChanged()
    }

    private func showImage() {
        let id = ids[index]
        step.show(images[id], isPreparing: images[id] == nil && photo(id)?.state != .failed)
    }

    /// Every photo of the pick, ahead of the person, so the next one is there when they get to it.
    private func decodeImages() {
        for id in ids where images[id] == nil && decoding[id] == nil {
            guard let jpeg = photo(id)?.prepared?.jpeg else {
                continue
            }
            decoding[id] = Task { [weak self] in
                let image = await Self.image(from: jpeg)
                guard let self, !Task.isCancelled else {
                    return
                }
                decoding[id] = nil
                images[id] = image
                showImage()
            }
        }
    }

    private func creditChanged() {
        let credit = step.editor.draft
        sheet?.isConfirmEnabled = credit.isComplete
        guard credit.takenBySubmitter == showsSomeoneElse else {
            return
        }
        showsSomeoneElse = !credit.takenBySubmitter
        sheet?.contentDidChange()
    }

    private func save() {
        let id = ids[index]
        let credit = step.editor.draft
        model.edit { $0.updateAddedPhoto(id) { $0.credit = credit } }
    }

    private func next() {
        save()
        guard index < ids.count - 1 else {
            sheet?.dismiss(animated: true)
            return
        }
        index += 1
        showStep()
    }

    private func previous() {
        save()
        index -= 1
        showStep()
    }
}
