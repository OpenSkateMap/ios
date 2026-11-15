import MapKit
import QuartzCore
import UIKit

// MARK: - GlobeFlight

@MainActor
final class GlobeFlight: NSObject {

    // MARK: Computed Properties

    var isFlying: Bool {
        path != nil
    }

    // MARK: Properties

    var onFrame: ((MKMapCamera) -> Void)?
    var onArrival: (() -> Void)?

    private(set) var path: FlightPath?

    private var startTime: CFTimeInterval = 0
    private var displayLink: CADisplayLink?

    // MARK: Functions

    func fly(_ path: FlightPath, onScreen: Bool) {
        guard onScreen, !UIAccessibility.isReduceMotionEnabled else {
            interrupt()
            onFrame?(path.camera(atProgress: 1))
            onArrival?()
            return
        }
        self.path = path
        startTime = CACurrentMediaTime()
        if displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(step(_:)))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 120)
            link.add(to: .main, forMode: .common)
            displayLink = link
        }
    }

    func interrupt() {
        path = nil
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc
    private func step(_ link: CADisplayLink) {
        guard let path else {
            return
        }
        let progress = min(max((link.targetTimestamp - startTime) / path.duration, 0), 1)
        onFrame?(path.camera(atProgress: progress))
        guard progress >= 1 else {
            return
        }
        interrupt()
        onArrival?()
    }
}

// MARK: - FlightPath

struct FlightPath {

    // MARK: Static Properties

    private static let legDuration: CFTimeInterval = 1.7
    private static let descentDuration: CFTimeInterval = 3

    // MARK: Computed Properties

    var destination: MKMapCamera {
        legs[legs.count - 1].to
    }

    // MARK: Properties

    let legs: [(from: MKMapCamera, to: MKMapCamera)]
    let duration: CFTimeInterval

    // MARK: Lifecycle

    static func descent(from: MKMapCamera, to: MKMapCamera) -> FlightPath {
        FlightPath(legs: [(from, to)], duration: descentDuration)
    }

    static func arc(from: MKMapCamera, to: MKMapCamera) -> FlightPath {
        let distance = MKMapPoint(from.centerCoordinate).distance(to: MKMapPoint(to.centerCoordinate))
        let apex = MKMapCamera(
            lookingAtCenter: GlobeCameraMath.interpolate(from.centerCoordinate, to.centerCoordinate, by: 0.5),
            fromDistance: min(GlobeCameraMath.orbitDistance, max(distance * 2.5, 1_500_000)),
            pitch: 0,
            heading: 0,
        )
        return FlightPath(legs: [(from, apex), (apex, to)], duration: legDuration * 2)
    }

    // MARK: Functions

    func camera(atProgress progress: Double) -> MKMapCamera {
        let scaled = progress * Double(legs.count)
        let index = min(Int(scaled), legs.count - 1)
        let leg = legs[index]
        let local = min(max(scaled - Double(index), 0), 1)
        return GlobeCameraMath.flightCamera(from: leg.from, to: leg.to, eased: GlobeCameraMath.eased(local))
    }
}

// MARK: - GlobeCameraMath

enum GlobeCameraMath {

    // MARK: Static Properties

    static let orbitDistance: CLLocationDistance = 40_000_000
    static let restingLatitude: CLLocationDegrees = 26

    // MARK: Static Functions

    static func orbitCamera(longitude: CLLocationDegrees) -> MKMapCamera {
        // MapKit throws on an invalid coordinate: wrap the longitude here, once.
        let wrapped = (longitude + 180).truncatingRemainder(dividingBy: 360)
        let normalized = (wrapped < 0 ? wrapped + 360 : wrapped) - 180
        return MKMapCamera(
            lookingAtCenter: CLLocationCoordinate2D(latitude: restingLatitude, longitude: normalized),
            fromDistance: orbitDistance,
            pitch: 0,
            heading: 0,
        )
    }

    static func eased(_ progress: Double) -> Double {
        progress < 0.5 ? 4 * progress * progress * progress : 1 - pow(-2 * progress + 2, 3) / 2
    }

    static func flightCamera(from: MKMapCamera, to: MKMapCamera, eased: Double) -> MKMapCamera {
        let fromLog = log(from.centerCoordinateDistance)
        let toLog = log(to.centerCoordinateDistance)
        let distanceLog = fromLog + (toLog - fromLog) * eased
        let (low, high) = fromLog <= toLog ? (from, to) : (to, from)
        let lowLog = min(fromLog, toLog)
        let highLog = max(fromLog, toLog)
        let altitude = highLog > lowLog ? (distanceLog - lowLog) / (highLog - lowLog) : eased
        let tilt = min(altitude / 0.6, 1)
        let tiltEased = tilt * tilt * (3 - 2 * tilt)
        return MKMapCamera(
            lookingAtCenter: interpolate(low.centerCoordinate, high.centerCoordinate, by: pow(altitude, 4)),
            fromDistance: exp(distanceLog),
            pitch: low.pitch + (high.pitch - low.pitch) * tiltEased,
            heading: interpolate(heading: low.heading, high.heading, by: tiltEased),
        )
    }

    static func interpolate(_ from: CLLocationCoordinate2D,
                            _ to: CLLocationCoordinate2D,
                            by weight: Double) -> CLLocationCoordinate2D {
        var longitudeDelta = to.longitude - from.longitude
        if longitudeDelta > 180 {
            longitudeDelta -= 360
        } else if longitudeDelta < -180 {
            longitudeDelta += 360
        }
        var longitude = from.longitude + longitudeDelta * weight
        if longitude > 180 {
            longitude -= 360
        } else if longitude < -180 {
            longitude += 360
        }
        return CLLocationCoordinate2D(latitude: from.latitude + (to.latitude - from.latitude) * weight, longitude: longitude)
    }

    static func interpolate(heading from: CLLocationDirection,
                            _ to: CLLocationDirection,
                            by weight: Double) -> CLLocationDirection {
        var delta = (to - from).truncatingRemainder(dividingBy: 360)
        if delta > 180 {
            delta -= 360
        } else if delta < -180 {
            delta += 360
        }
        let heading = (from + delta * weight).truncatingRemainder(dividingBy: 360)
        return heading < 0 ? heading + 360 : heading
    }
}
