public import CoreLocation

// MARK: - LocationManager

public struct LocationManager: Sendable {
    public var currentLocation: @Sendable () async throws -> CLLocationCoordinate2D
    /// Reading it never asks for permission.
    public var isAuthorized: @Sendable () -> Bool
    /// The last fix the system has, possibly from an earlier launch, without waiting for a new one; nil unless allowed.
    public var lastLocation: @Sendable () -> CLLocationCoordinate2D?

    public init(currentLocation: @escaping @Sendable () async throws -> CLLocationCoordinate2D,
                isAuthorized: @escaping @Sendable () -> Bool,
                lastLocation: @escaping @Sendable () -> CLLocationCoordinate2D?) {
        self.currentLocation = currentLocation
        self.isAuthorized = isAuthorized
        self.lastLocation = lastLocation
    }
}

// MARK: - LocationError

public enum LocationError: Error, Equatable, Sendable {
    case denied
    case unavailable
}

extension LocationManager {
    /// Updates keep coming without a location while there's no fix, so it gives up after `fixTimeout`, counted from
    /// when the permission prompt is answered: time spent reading it isn't time spent waiting for a fix.
    public static let live = LocationManager {
        try await withThrowingTaskGroup(of: CLLocationCoordinate2D.self) { group in
            let (decided, decide) = AsyncStream<Void>.makeStream()
            if CLLocationManager().authorizationStatus != .notDetermined {
                decide.yield()
            }
            group.addTask {
                let session = CLServiceSession(authorization: .whenInUse)
                defer {
                    session.invalidate()
                    decide.finish()
                }
                for try await update in CLLocationUpdate.liveUpdates() {
                    if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                        throw LocationError.denied
                    }
                    if !update.authorizationRequestInProgress {
                        decide.yield()
                    }
                    if let location = update.location {
                        return location.coordinate
                    }
                }
                throw LocationError.unavailable
            }
            group.addTask {
                for await _ in decided {
                    break
                }
                try await Task.sleep(for: fixTimeout)
                throw LocationError.unavailable
            }
            defer { group.cancelAll() }
            guard let coordinate = try await group.next() else {
                throw LocationError.unavailable
            }
            return coordinate
        }
    } isAuthorized: {
        [.authorizedWhenInUse, .authorizedAlways].contains(CLLocationManager().authorizationStatus)
    } lastLocation: {
        CLLocationManager().location?.coordinate
    }

    private static let fixTimeout = Duration.seconds(15)

    public static let preview = LocationManager {
        CLLocationCoordinate2D(latitude: 51.5066, longitude: -0.1169)
    } isAuthorized: {
        true
    } lastLocation: {
        CLLocationCoordinate2D(latitude: 51.5066, longitude: -0.1169)
    }
}
