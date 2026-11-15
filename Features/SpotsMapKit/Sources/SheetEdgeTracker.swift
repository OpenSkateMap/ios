import UIKit

/// Measured on iOS 27: the sheet's pan targets run with its new frame already set, before it draws, so reading it
/// there moves the chrome in the same frame; a display link reading the presentation layer is a frame behind.
@MainActor
final class SheetEdgeTracker: NSObject {

    // MARK: Types

    enum Motion {
        case immediate
        case spring(UISpringTimingParameters)
    }

    // MARK: Static Properties

    private static let panSearchDepth = 8
    /// UIKit's sheet springs (iOS 27 `_UISheetPresentationMetrics`), measured against the sheet within 0.4 pt.
    private static let springResponse = 0.344144
    private static let highSpeed: CGFloat = 1000

    // MARK: Properties

    var onChange: ((Motion) -> Void)?

    private(set) var top: CGFloat?

    private weak var sheet: UIViewController?
    private var hookedPans = Set<ObjectIdentifier>()

    // MARK: Static Functions

    private static func releaseSpring(speed: CGFloat) -> UISpringTimingParameters {
        let stiffness = pow(2 * .pi / springResponse, 2)
        let dampingRatio = speed >= highSpeed ? 0.8 : 1
        return UISpringTimingParameters(
            mass: 1,
            stiffness: stiffness,
            damping: 2 * dampingRatio * sqrt(stiffness),
            initialVelocity: .zero,
        )
    }

    // MARK: Functions

    func track(_ sheet: UIViewController) {
        self.sheet = sheet
        hookedPans = []
        guard let transition = sheet.transitionCoordinator else {
            hookPans()
            report(edge(of: sheet), .immediate)
            return
        }
        transition.animate { [weak self] _ in
            guard let self else {
                return
            }
            report(restingEdge(of: sheet), settleSpring(of: sheet).map(Motion.spring) ?? .immediate)
        } completion: { [weak self] _ in
            self?.hookPans()
            self?.report(self?.edge(of: sheet), .immediate)
        }
    }

    func dismissing() {
        guard let sheet else {
            return
        }
        guard let transition = sheet.transitionCoordinator else {
            report(nil, .immediate)
            return
        }
        transition.animate { [weak self] context in
            guard !context.isInteractive else {
                return
            }
            self?.report(nil, .immediate)
        } completion: { [weak self] context in
            guard let self, !context.isCancelled, self.sheet === sheet else {
                return
            }
            top = nil
        }
    }

    private func edge(of sheet: UIViewController) -> CGFloat? {
        guard sheet.presentingViewController != nil || sheet.isBeingPresented,
              let view = sheet.presentationController?.presentedView,
              let window = view.window else {
            return nil
        }
        return view.convert(view.bounds, to: window).minY
    }

    /// Where a sheet being presented comes to rest. It has its final size but not yet its floating inset, which leaves
    /// as much room below it as at its sides (iOS 26), so its own frame would put the edge that much too high.
    private func restingEdge(of sheet: UIViewController) -> CGFloat? {
        guard let view = sheet.presentationController?.presentedView,
              let container = sheet.presentationController?.containerView,
              let window = container.window else {
            return nil
        }
        // The frame, not the bounds: a floating sheet is its full-width view scaled down by a transform.
        let bounds = container.convert(container.bounds, to: window)
        let size = view.frame.size
        let inset = max(0, (bounds.width - size.width) / 2)
        return bounds.maxY - inset - size.height
    }

    private func report(_ edge: CGFloat?, _ motion: Motion) {
        top = edge
        onChange?(motion)
    }

    private func hookPans() {
        guard let container = sheet?.presentationController?.presentedView else {
            return
        }
        hookPans(in: container, depth: 0)
    }

    private func hookPans(in view: UIView, depth: Int) {
        for case let pan as UIPanGestureRecognizer in view.gestureRecognizers ?? []
            where hookedPans.insert(ObjectIdentifier(pan)).inserted {
            pan.addTarget(self, action: #selector(panned(_:)))
        }
        guard depth < Self.panSearchDepth else {
            return
        }
        for subview in view.subviews {
            hookPans(in: subview, depth: depth + 1)
        }
    }

    @objc
    private func panned(_ pan: UIPanGestureRecognizer) {
        guard let sheet, let edge = edge(of: sheet) else {
            return
        }
        switch pan.state {
        case .ended, .cancelled, .failed:
            let speed = abs(pan.velocity(in: nil).y)
            report(edge, .spring(settleSpring(of: sheet) ?? Self.releaseSpring(speed: speed)))

        default:
            if edge != top {
                report(edge, .immediate)
            }
        }
    }

    private func settleSpring(of sheet: UIViewController) -> UISpringTimingParameters? {
        var view = sheet.presentationController?.presentedView
        let container = sheet.presentationController?.containerView
        while let current = view, current !== container {
            if let spring = current.layer.animation(forKey: "position") as? CASpringAnimation {
                return UISpringTimingParameters(
                    mass: spring.mass,
                    stiffness: spring.stiffness,
                    damping: spring.damping,
                    initialVelocity: CGVector(dx: 0, dy: spring.initialVelocity),
                )
            }
            view = current.superview
        }
        return nil
    }
}
