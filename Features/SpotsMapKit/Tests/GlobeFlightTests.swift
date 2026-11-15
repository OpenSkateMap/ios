import CustomDump
import MapKit
import Testing
@testable import SpotsMapKit

// MARK: - GlobeFlightTests

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct GlobeFlightTests {
    private let london = MKMapCamera(
        lookingAtCenter: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12),
        fromDistance: 40000,
        pitch: 0,
        heading: 0,
    )
    private let barcelona = MKMapCamera(
        lookingAtCenter: CLLocationCoordinate2D(latitude: 41.39, longitude: 2.17),
        fromDistance: 30000,
        pitch: 0,
        heading: 0,
    )

    @Test
    func `a descent starts on the planet and lands exactly on the city`() {
        let planet = GlobeCameraMath.orbitCamera(longitude: 0)
        let path = FlightPath.descent(from: planet, to: london)

        let start = path.camera(atProgress: 0)
        let end = path.camera(atProgress: 1)

        expectNoDifference(start.centerCoordinateDistance.rounded(), planet.centerCoordinateDistance.rounded())
        expectNoDifference(end.centerCoordinateDistance.rounded(), london.centerCoordinateDistance.rounded())
        expectNoDifference(end.centerCoordinate.latitude, london.centerCoordinate.latitude, accuracy: 0.000_001)
        expectNoDifference(end.centerCoordinate.longitude, london.centerCoordinate.longitude, accuracy: 0.000_001)
    }

    @Test
    func `an arc between far cities climbs above both and lands on the second`() {
        let path = FlightPath.arc(from: london, to: barcelona)

        let top = path.camera(atProgress: 0.5)
        let end = path.camera(atProgress: 1)

        #expect(top.centerCoordinateDistance > london.centerCoordinateDistance * 10)
        #expect(top.centerCoordinateDistance > barcelona.centerCoordinateDistance * 10)
        expectNoDifference(end.centerCoordinateDistance.rounded(), barcelona.centerCoordinateDistance.rounded())
        expectNoDifference(end.centerCoordinate.longitude, barcelona.centerCoordinate.longitude, accuracy: 0.000_001)
    }

    @Test
    func `the planet camera wraps any longitude into range`() {
        expectNoDifference(GlobeCameraMath.orbitCamera(longitude: 190).centerCoordinate.longitude, -170, accuracy: 0.000_001)
        expectNoDifference(GlobeCameraMath.orbitCamera(longitude: -540).centerCoordinate.longitude, -180, accuracy: 0.000_001)
    }

    @Test
    func `the midpoint across the antimeridian goes the short way round`() {
        let midpoint = GlobeCameraMath.interpolate(
            CLLocationCoordinate2D(latitude: 0, longitude: 170),
            CLLocationCoordinate2D(latitude: 0, longitude: -170),
            by: 0.5,
        )

        expectNoDifference(abs(midpoint.longitude), 180, accuracy: 0.000_001)
    }
}

private func expectNoDifference(_ actual: Double,
                                _ expected: Double,
                                accuracy: Double,
                                sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(
        abs(actual - expected) <= accuracy,
        "\(actual) is not within \(accuracy) of \(expected)",
        sourceLocation: sourceLocation,
    )
}
