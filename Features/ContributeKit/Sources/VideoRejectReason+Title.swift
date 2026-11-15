import ReviewKit

extension VideoRejectReason {
    nonisolated var title: String {
        switch self {
        case .duplicate: ContributeKitStrings.VideoRejectReason.duplicate
        case .wrongSpot: ContributeKitStrings.VideoRejectReason.wrongSpot
        case .notSkating: ContributeKitStrings.VideoRejectReason.notSkating
        case .inappropriate: ContributeKitStrings.VideoRejectReason.inappropriate
        }
    }
}
