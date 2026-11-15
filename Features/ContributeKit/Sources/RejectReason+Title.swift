import ReviewKit

extension RejectReason {
    nonisolated var title: String {
        switch self {
        case .duplicate: ContributeKitStrings.RejectReason.duplicate
        case .notASpot: ContributeKitStrings.RejectReason.notASpot
        case .wrongLocation: ContributeKitStrings.RejectReason.wrongLocation
        case .privateProperty: ContributeKitStrings.RejectReason.privateProperty
        case .photoRights: ContributeKitStrings.RejectReason.photoRights
        }
    }
}
