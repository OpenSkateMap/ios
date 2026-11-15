import CustomDump
import MapKit
import Testing
@testable import SpotsMapKit

// MARK: - PinReuseTests

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PinReuseTests {
    @Test
    func `a reused pin still clusters`() {
        let pin = SpotAnnotationView(annotation: nil, reuseIdentifier: SpotAnnotationView.reuseIdentifier)

        pin.prepareForReuse()

        expectNoDifference(pin.clusteringIdentifier, SpotAnnotationView.clusterID)
        expectNoDifference(pin.displayPriority, .defaultHigh)
    }

    @Test
    func `a reused cluster still gives way to others`() {
        let cluster = SpotClusterAnnotationView(annotation: nil, reuseIdentifier: SpotClusterAnnotationView.reuseIdentifier)

        cluster.prepareForReuse()

        expectNoDifference(cluster.displayPriority, .defaultHigh)
    }
}
