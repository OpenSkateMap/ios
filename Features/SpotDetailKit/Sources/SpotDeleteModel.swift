import CollectionsKit
import ComponentKit
import FactoryKit
import Observation
import os
import SpotModelKit
import SpotsKit

@MainActor
@Observable
final class SpotDeleteModel {

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "spot-delete")

    // MARK: Computed Properties

    var canDelete: Bool {
        reason != nil && !isDeleting
    }

    // MARK: Properties

    let spot: SpotIndex
    var reason: SpotRemovalReason?
    private(set) var isDeleting = false

    @ObservationIgnored @Injected(\.spotsSession) private var spots
    @ObservationIgnored @Injected(\.collectionsSession) private var collections

    // MARK: Lifecycle

    init(spot: SpotIndex) {
        self.spot = spot
    }

    // MARK: Functions

    func delete() async throws {
        guard let reason, canDelete else {
            return
        }
        isDeleting = true
        defer { isDeleting = false }
        try await spots.takeDown(spot.id, reason: reason)
    }

    /// Undo is the app's only way back, so a failed one is offered again.
    func restore() {
        Task { [spot, spots, collections] in
            do {
                try await spots.restore(spot.id)
                if spot.isPrivate {
                    await collections.syncNow()
                }
            } catch {
                Self.logger.error("A restore didn't go through: \(String(describing: error), privacy: .public)")
                ToastView.show(
                    .icon(predefinedIcon: .failure, title: SpotDetailKitStrings.Spot.Delete.restoreFailed),
                    actionTitle: SpotDetailKitStrings.Spot.Details.retry,
                ) {
                    self.restore()
                }
            }
        }
    }
}
