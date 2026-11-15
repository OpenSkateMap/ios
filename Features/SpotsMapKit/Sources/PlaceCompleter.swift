import MapKit

// MARK: - PlaceCompleter

@MainActor
final class PlaceCompleter: NSObject {

    // MARK: Properties

    var onUpdate: (([MKLocalSearchCompletion]) -> Void)?

    private let completer = MKLocalSearchCompleter()

    // MARK: Lifecycle

    override init() {
        super.init()

        completer.resultTypes = .address
        completer.addressFilter = MKAddressFilter(including: [.locality, .subLocality, .administrativeArea, .country])
        completer.delegate = self
    }

    // MARK: Static Functions

    static func place(for completion: MKLocalSearchCompletion) async -> (region: MKCoordinateRegion, mark: MKPointAnnotation)? {
        guard let response = try? await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start(),
              let item = response.mapItems.first else {
            return nil
        }
        let mark = MKPointAnnotation()
        mark.coordinate = item.location.coordinate
        mark.title = item.name ?? completion.title
        let region = response.boundingRegion
        if region.span.latitudeDelta > 0.001 {
            return (region, mark)
        }
        return (MKCoordinateRegion(center: mark.coordinate, latitudinalMeters: 8000, longitudinalMeters: 8000), mark)
    }

    // MARK: Functions

    func complete(_ query: String, near region: MKCoordinateRegion?) {
        if let region {
            completer.region = region
        }
        guard !query.isEmpty else {
            completer.cancel()
            onUpdate?([])
            return
        }
        completer.queryFragment = query
    }

}

// MARK: @MainActor MKLocalSearchCompleterDelegate

/// MapKit calls the delegate on the main thread, where the completer lives.
extension PlaceCompleter: @MainActor MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onUpdate?(completer.results)
    }

    func completer(_: MKLocalSearchCompleter, didFailWithError _: any Error) {
        onUpdate?([])
    }
}
