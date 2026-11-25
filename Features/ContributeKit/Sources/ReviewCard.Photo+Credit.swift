import ReviewKit

extension ReviewCard.Photo {
    var creditText: String {
        switch (attribution, clip != nil) {
        case (.someoneElse(let name), false): ContributeKitStrings.ReviewCard.Credit.someoneElse(name)
        case (.someoneElse(let name), true): ContributeKitStrings.ReviewCard.Credit.Video.someoneElse(name)
        case (.spot, _): ContributeKitStrings.ReviewCard.Credit.existing
        case (.submitter, false): ContributeKitStrings.ReviewCard.Credit.submitter
        case (.submitter, true): ContributeKitStrings.ReviewCard.Credit.Video.submitter
        }
    }
}
