import CoreLocation
import FactoryKit
import LocationKit
import Observation
import os
import SpotModelKit
import SQLiteData
import SQLiteKit

@MainActor
@Observable
final class SpotSheetModel {

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "spot-sheet")

    // MARK: Computed Properties

    var page: SpotPage {
        storedPage
    }

    var isGone: Bool {
        loadedID != nil && loadedID == spotID && storedPage.spot == nil
    }

    // MARK: Properties

    private(set) var spotID: String?
    private(set) var address: String?

    private var loadedID: String?

    @ObservationIgnored @Fetch private var storedPage = SpotPage()
    @ObservationIgnored @Injected(\.geocodingManager) private var geocoding
    @ObservationIgnored private var loading: Task<Void, Never>?
    @ObservationIgnored private var geocodingTask: Task<Void, Never>?
    @ObservationIgnored private var geocoded: CLLocationCoordinate2D?

    // MARK: Lifecycle

    isolated deinit {
        loading?.cancel()
        geocodingTask?.cancel()
    }

    // MARK: Functions

    func show(_ id: String) {
        guard id != spotID else {
            return
        }
        spotID = id
        loadedID = nil
        address = nil
        geocoded = nil
        loading?.cancel()
        loading = Task { [weak self] in
            do {
                try await self?.$storedPage.load(SpotPageRequest(id: id), scheduler: .backgroundRead)
            } catch {
                Self.logger.error("Loading the spot failed: \(String(describing: type(of: error)), privacy: .public)")
            }
            guard !Task.isCancelled, self?.spotID == id else {
                return
            }
            self?.loadedID = id
            for await spot in Observations({ [weak self] in self?.storedPage.spot }) {
                guard let self, !Task.isCancelled else {
                    return
                }
                geocodeIfNeeded(spot)
            }
        }
    }

    private func geocodeIfNeeded(_ spot: SpotIndex?) {
        guard let spot else {
            return
        }
        let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        guard geocoded?.latitude != coordinate.latitude || geocoded?.longitude != coordinate.longitude else {
            return
        }
        geocoded = coordinate
        geocodingTask?.cancel()
        geocodingTask = Task { [weak self, geocoding] in
            let address = await geocoding.address(coordinate)
            guard !Task.isCancelled else {
                return
            }
            self?.address = address
        }
    }
}
