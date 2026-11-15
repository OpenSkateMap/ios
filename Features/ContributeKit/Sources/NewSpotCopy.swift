// MARK: - NewSpotCopy

struct NewSpotCopy {

    // MARK: Properties

    let title: String
    let submitLabel: String
    let discardMessage: String
    let discardConfirm: String
    /// Nil in review: the queue's notice says why.
    let saveFailedTitle: String?

    // MARK: Lifecycle

    init(mode: NewSpotForm.Mode, goesToCurators: Bool) {
        switch mode {
        case .new:
            title = ContributeKitStrings.NewSpot.title
            submitLabel = ContributeKitStrings.NewSpot.A11y.submit
            discardMessage = ContributeKitStrings.NewSpot.Discard.message
            discardConfirm = ContributeKitStrings.NewSpot.Discard.spot
            saveFailedTitle = ContributeKitStrings.NewSpot.SaveFailed.title

        case .edit:
            title = goesToCurators ? ContributeKitStrings.NewSpot.editTitle : ContributeKitStrings.NewSpot.directEditTitle
            submitLabel = goesToCurators ? ContributeKitStrings.NewSpot.A11y.sendEdit : ContributeKitStrings.NewSpot.A11y.saveEdit
            discardMessage = ContributeKitStrings.NewSpot.Discard.editMessage
            discardConfirm = ContributeKitStrings.NewSpot.Discard.edit
            saveFailedTitle = ContributeKitStrings.NewSpot.SaveFailed.editTitle

        case .review:
            title = ContributeKitStrings.ReviewEdit.title
            submitLabel = ContributeKitStrings.ReviewEdit.approve
            discardMessage = ContributeKitStrings.ReviewEdit.Discard.message
            discardConfirm = ContributeKitStrings.ReviewEdit.Discard.confirm
            saveFailedTitle = nil
        }
    }
}

extension NewSpotModel {
    var copy: NewSpotCopy {
        NewSpotCopy(mode: form.mode, goesToCurators: goesToCurators)
    }
}
