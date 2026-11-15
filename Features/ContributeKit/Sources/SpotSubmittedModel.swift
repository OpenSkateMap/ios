import Foundation
import Observation
import SQLiteData

@MainActor
@Observable
final class SpotSubmittedModel {

    // MARK: Properties

    let title: String
    let location: NewSpotForm.Location
    let collection: String?
    let isEdit: Bool
    let isReviewed: Bool

    @ObservationIgnored @Fetch var status: SubmittedSpotStatus

    // MARK: Lifecycle

    init(id: String, title: String, location: NewSpotForm.Location, isEdit: Bool, isReviewed: Bool, collection: String? = nil) {
        self.title = title
        self.location = location
        self.isEdit = isEdit
        self.isReviewed = isReviewed
        self.collection = collection
        _status = Fetch(wrappedValue: .sending, SubmittedSpotStatusRequest(id: id))
    }
}
