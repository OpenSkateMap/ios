import CoreLocation
import Foundation
import Observation
import os
import SQLiteData
import SQLiteKit

@MainActor
@Observable
final class SpotSubmittedModel {

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "contribute")
    private static let nextSpotsLimit = 2
    /// Farther than this from the spot just sent isn't "around here".
    private static let aroundHereMeters = 5000

    // MARK: Computed Properties

    /// The nearest public spots without a photo around the one just sent, which never counts itself.
    var nextSpots: [NearYou.Spot] {
        let sent = [editedSpotID, status.spotID].compactMap(\.self)
        return Array(
            nearby.spots
                .filter { spot in
                    spot.ask == .noPhoto && !sent.contains(spot.id) && (spot.distanceMeters ?? .max) <= Self.aroundHereMeters
                }
                .prefix(Self.nextSpotsLimit)
        )
    }

    // MARK: Properties

    let title: String
    let location: NewSpotForm.Location
    let collection: String?
    let isEdit: Bool
    let isReviewed: Bool
    let editedSpotID: String?

    @ObservationIgnored @Fetch var status: SubmittedSpotStatus
    @ObservationIgnored @Fetch(NearYouRequest(origin: nil)) var nearby = NearYou()

    // MARK: Lifecycle

    init(id: String,
         title: String,
         location: NewSpotForm.Location,
         isEdit: Bool,
         isReviewed: Bool,
         collection: String? = nil,
         editedSpotID: String? = nil) {
        self.title = title
        self.location = location
        self.isEdit = isEdit
        self.isReviewed = isReviewed
        self.collection = collection
        self.editedSpotID = editedSpotID
        _status = Fetch(wrappedValue: .sending, SubmittedSpotStatusRequest(id: id))
    }

    // MARK: Functions

    /// Distances are from the spot just sent: "around here" is around it.
    func loadNextSpots() async {
        let origin = NearYouRequest.Origin(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            isPersonal: true,
        )
        do {
            try await $nearby.load(NearYouRequest(origin: origin), scheduler: .backgroundRead)
        } catch {
            Self.logger.error("Next spots couldn't load: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
