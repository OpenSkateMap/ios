import ReviewKit

extension ReviewCard.Photo {
    var creditText: String {
        switch attribution {
        case .someoneElse(let name): ContributeKitStrings.ReviewCard.Credit.someoneElse(name)
        case .spot: ContributeKitStrings.ReviewCard.Credit.existing
        case .submitter: ContributeKitStrings.ReviewCard.Credit.submitter
        }
    }
}
