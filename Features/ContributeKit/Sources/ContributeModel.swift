import AccountKit
import ContributionsKit
import FactoryKit
import LocationKit
import MapKit
import Observation
import os
import ReviewKit
import SQLiteData

@MainActor
@Observable
final class ContributeModel {

    // MARK: Types

    struct Summary: Equatable {
        var added = 0
        var onTheMap = 0
        var waiting = 0
    }

    enum Discard: Equatable {
        case done
        case alreadySending
        case failed
    }

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "contribute")

    // MARK: Computed Properties

    var summary: Summary {
        spots.reduce(into: Summary()) { summary, spot in
            switch spot.badge {
            case .approved where !spot.isEdit: summary.onTheMap += 1
            case .sending, .waitingForNetwork, .pending: summary.waiting += 1
            case .approved, .failed, .rejected, .private, .removed: break
            }
            // A spot an admin took down no longer counts, as on the profile.
            if !spot.isEdit, !spot.isRemoved {
                summary.added += 1
            }
        }
    }

    var reviewWaiting: Int? {
        guard reviewSession.isQueueKnown else {
            return nil
        }
        return reviewSession.cards.count + reviewSession.videoCards.count
    }

    var showsReviewQueue: Bool {
        isCurator || (reviewWaiting ?? 0) > 0
    }

    var isCurator: Bool {
        authSession.isCurator
    }

    // MARK: Properties

    @ObservationIgnored @Fetch(YourSpotsRequest()) var spots = []
    @ObservationIgnored @Fetch(NearYouRequest(origin: nil)) var nearYou = NearYou()

    @ObservationIgnored @Injected(\.contributionsSession) private var session
    @ObservationIgnored @Injected(\.authSession) private var authSession
    @ObservationIgnored @Injected(\.reviewSession) private var reviewSession
    @ObservationIgnored @Injected(\.locationManager) private var locationManager
    @ObservationIgnored private var nearYouOrigin: NearYouRequest.Origin?

    // MARK: Functions

    /// A pull the person started; false when the submission history didn't come back (the queue reports its own).
    func refresh() async -> Bool {
        async let queue: Void = loadReviewQueue()
        let refreshed = await session.pull()
        await queue
        return refreshed
    }

    /// Around the person's last fix once allowed (never asked for here), else the map's last camera.
    func loadNearYou() async {
        let origin: NearYouRequest.Origin? = if locationManager.isAuthorized(), let here = locationManager.lastLocation() {
            .rounded(latitude: here.latitude, longitude: here.longitude, isPersonal: true)
        } else {
            MKCoordinateRegion.storedLastMap.map {
                .rounded(latitude: $0.center.latitude, longitude: $0.center.longitude, isPersonal: false)
            }
        }
        guard origin != nearYouOrigin else {
            return
        }
        nearYouOrigin = origin
        do {
            try await $nearYou.load(NearYouRequest(origin: origin))
        } catch {
            Self.logger.error("Near You couldn't load: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    func loadReviewQueue() async {
        await reviewSession.load()
    }

    func retry(_ id: String) async -> Bool {
        do {
            try await session.retry(id)
            return true
        } catch {
            Self.logger.error("Retry failed: \(String(describing: type(of: error)), privacy: .public)")
            return false
        }
    }

    func discard(_ id: String) async -> Discard {
        do {
            return try await session.discard(id) ? .done : .alreadySending
        } catch {
            Self.logger.error("Discard failed: \(String(describing: type(of: error)), privacy: .public)")
            return .failed
        }
    }
}
