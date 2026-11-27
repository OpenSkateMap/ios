import Foundation
import SpotModelKit

// MARK: - YourSpot

struct YourSpot: Identifiable, Equatable, Sendable {
    enum Badge: Equatable, Sendable {
        case sending
        case waitingForNetwork
        case failed(reason: String)
        case pending
        case approved
        case rejected(reason: String?, wayBack: WayBack)
        case `private`(collection: String?)
        case removed(reason: String)
    }

    /// What a rejected spot can do next: a line phrased from the reason, and what its button opens.
    struct WayBack: Equatable, Sendable {
        enum Action: Equatable, Sendable {
            case newSpot
            case suggestEdit(spotID: String)
            /// A duplicate's photos belong on the spot that's already there.
            case addPhotos(spotID: String)
        }

        let line: String
        let action: Action?
    }

    var isRemoved: Bool {
        if case .removed = badge {
            return true
        }
        return false
    }

    let id: String
    let title: String
    let isEdit: Bool
    let kind: SpotKind
    let cityName: String?
    /// The cover's photo key once the server has it; unsent entries show only their ThumbHash.
    let coverKey: String?
    let thumbhash: String?
    let badge: Badge
    let spotID: String?
    let date: Date
    let isUnsent: Bool

}

extension YourSpot.Badge {
    var title: String {
        switch self {
        case .sending: ContributeKitStrings.Contribute.YourSpots.Badge.sending
        case .waitingForNetwork: ContributeKitStrings.Contribute.YourSpots.Badge.waitingForNetwork
        case .failed: ContributeKitStrings.Contribute.YourSpots.Badge.failed
        case .pending: ContributeKitStrings.Contribute.YourSpots.Badge.pending
        case .approved: ContributeKitStrings.Contribute.YourSpots.Badge.approved
        case .rejected: ContributeKitStrings.Contribute.YourSpots.Badge.rejected
        case .private: ContributeKitStrings.Contribute.YourSpots.Badge.private
        case .removed: ContributeKitStrings.Contribute.YourSpots.Badge.removed
        }
    }
}

extension YourSpot.WayBack.Action {
    var title: String {
        switch self {
        case .newSpot, .suggestEdit: ContributeKitStrings.Contribute.YourSpots.tryAgain
        case .addPhotos: ContributeKitStrings.Contribute.NearYou.addPhotos
        }
    }
}
