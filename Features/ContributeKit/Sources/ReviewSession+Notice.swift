import ReviewKit

extension ReviewSession.Notice {
    var toast: (title: String, subtitle: String?) {
        switch self {
        case .undoFailed(let reason): (ContributeKitStrings.ReviewNotice.Undo.title, reason.undoReason)
        default: (message, nil)
        }
    }

    var loadFailureMessage: String {
        switch self {
        case .offline: ContributeKitStrings.ReviewQueue.Failed.offline
        case .signedOut: ContributeKitStrings.ReviewNotice.signedOut
        case .unavailable, .outsideYourCities, .changedSinceOpened, .refused,
             .undoFailed: ContributeKitStrings.ReviewQueue.Failed.unavailable
        }
    }

    private var message: String {
        switch self {
        case .offline: ContributeKitStrings.ReviewNotice.offline
        case .unavailable: ContributeKitStrings.ReviewNotice.unavailable
        case .signedOut: ContributeKitStrings.ReviewNotice.signedOut
        case .outsideYourCities: ContributeKitStrings.ReviewNotice.outsideYourCities
        case .changedSinceOpened: ContributeKitStrings.ReviewNotice.changedSinceOpened
        case .refused(let reason): reason
        case .undoFailed(let reason): reason.undoReason
        }
    }

    private var undoReason: String {
        switch self {
        case .offline: ContributeKitStrings.ReviewNotice.Undo.offline
        case .unavailable: ContributeKitStrings.ReviewNotice.Undo.unavailable
        case .undoFailed(let reason): reason.undoReason
        case .signedOut, .outsideYourCities, .changedSinceOpened, .refused: message
        }
    }
}
