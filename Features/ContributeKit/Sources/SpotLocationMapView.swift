import MapKit
import PinLayout
import UIKit

// MARK: - SpotLocationMapView

/// A live map that doesn't move, not a snapshot, so the Apple logo and Legal link stay as MapKit draws them (HIG).
final class SpotLocationMapView: UIView {

    // MARK: Properties

    var showsPin = true

    private var mapView: MKMapView?
    private let annotation = MKPointAnnotation()
    private var shown: CLLocationCoordinate2D?

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        mapView?.pin
            .all()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: 160)
    }

    // MARK: Functions

    func show(_ coordinate: CLLocationCoordinate2D) {
        guard shown?.latitude != coordinate.latitude || shown?.longitude != coordinate.longitude else {
            return
        }
        shown = coordinate
        annotation.coordinate = coordinate
        let mapView = mapView ?? makeMapView()
        mapView.setRegion(
            MKCoordinateRegion(center: coordinate, latitudinalMeters: 450, longitudinalMeters: 450),
            animated: false,
        )
    }

    private func makeMapView() -> MKMapView {
        let mapView = MKMapView()
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.accessibilityElementsHidden = true
        mapView.delegate = self
        if showsPin {
            mapView.addAnnotation(annotation)
        }
        addSubview(mapView)
        self.mapView = mapView
        setNeedsLayout()
        return mapView
    }
}

// MARK: MKMapViewDelegate

extension SpotLocationMapView: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        let identifier = "location-pin"
        let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            ?? MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        view.annotation = annotation
        view.image = LocationPin.image
        view.centerOffset = LocationPin.annotationCenterOffset
        return view
    }
}
