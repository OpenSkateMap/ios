import UIKit

// MARK: - PhotoViewerTransition

final class PhotoViewerTransition: NSObject, UIViewControllerTransitioningDelegate {

    // MARK: Properties

    private let sourceView: (Int) -> UIImageView?

    // MARK: Lifecycle

    init(sourceView: @escaping (Int) -> UIImageView?) {
        self.sourceView = sourceView
    }

    // MARK: Functions

    func animationController(forPresented _: UIViewController,
                             presenting _: UIViewController,
                             source _: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        Flight(opening: true, sourceView: sourceView)
    }

    func animationController(forDismissed _: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
        Flight(opening: false, sourceView: sourceView)
    }
}

// MARK: - Flight

private final class Flight: NSObject, UIViewControllerAnimatedTransitioning {

    // MARK: Static Properties

    /// The system photo viewer's tiling animations: `defaultAnimationDuration` opening, `PXSwipeDownTracker`'s final animation closing.
    private static let openingDuration: TimeInterval = 0.5
    private static let closingDuration: TimeInterval = 0.3
    private static let controlsReturnDuration: TimeInterval = 0.25

    // MARK: Properties

    private let opening: Bool
    private let sourceView: (Int) -> UIImageView?

    // MARK: Lifecycle

    init(opening: Bool, sourceView: @escaping (Int) -> UIImageView?) {
        self.opening = opening
        self.sourceView = sourceView
    }

    // MARK: Static Functions

    /// `isHidden`, not alpha: glass doesn't draw at partial opacity, and hiding it inside an animation dissolves it.
    private static func setCardControls(of viewer: PhotoViewerController, hidden: Bool) {
        for control in viewer.cardControls {
            control.isHidden = hidden
        }
    }

    // MARK: Functions

    func transitionDuration(using _: any UIViewControllerContextTransitioning?) -> TimeInterval {
        opening ? Self.openingDuration : Self.closingDuration
    }

    func animateTransition(using context: any UIViewControllerContextTransitioning) {
        let key: UITransitionContextViewControllerKey = opening ? .to : .from
        guard let viewer = context.viewController(forKey: key) as? PhotoViewerController else {
            context.completeTransition(!context.transitionWasCancelled)
            return
        }
        let container = context.containerView
        if opening {
            viewer.view.frame = context.finalFrame(for: viewer)
            container.addSubview(viewer.view)
            viewer.view.layoutIfNeeded()
        }
        let source = sourceView(viewer.index)
        guard !UIAccessibility.isReduceMotionEnabled,
              let source, source.window != nil,
              let image = viewer.clipFrame ?? (opening ? source.image : viewer.photoImage ?? source.image),
              let photoFrame = viewer.photoFrame else {
            crossfade(viewer, in: context)
            return
        }
        let cardFrame = source.convert(source.bounds, to: container)
        let cardRadius = source.layer.cornerRadius
        let photo = UIImageView(image: image)
        photo.contentMode = .scaleAspectFill
        photo.clipsToBounds = true
        photo.layer.cornerCurve = .continuous
        photo.frame = opening ? cardFrame : photoFrame
        photo.layer.cornerRadius = opening ? cardRadius : 0
        container.addSubview(photo)
        source.isHidden = true
        viewer.isPhotoHidden = true
        if opening {
            viewer.setSurroundingsVisible(false)
        }

        let distance = max(abs(cardFrame.midY - photoFrame.midY), 1)
        let speed = opening ? 0 : viewer.releaseVelocity.y / distance
        let timing = UISpringTimingParameters(dampingRatio: opening ? 0.84 : 1, initialVelocity: CGVector(dx: speed, dy: speed))
        let animator = UIViewPropertyAnimator(duration: transitionDuration(using: context), timingParameters: timing)
        animator.addAnimations {
            photo.frame = self.opening ? photoFrame : cardFrame
            photo.layer.cornerRadius = self.opening ? 0 : cardRadius
        }
        animator.addAnimations {
            UIView.animateKeyframes(withDuration: 0, delay: 0) {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: self.opening ? 1 : 0.4) {
                    viewer.setSurroundingsVisible(self.opening)
                }
            }
        }
        if opening {
            animator.addAnimations { Self.setCardControls(of: viewer, hidden: true) }
        }
        animator.addCompletion { _ in
            source.isHidden = false
            viewer.isPhotoHidden = false
            photo.removeFromSuperview()
            context.completeTransition(!context.transitionWasCancelled)
            // The flying copy covers the card until here, so the card's controls come back as it lands.
            if !self.opening {
                UIView.animate(withDuration: Self.controlsReturnDuration) { Self.setCardControls(of: viewer, hidden: false) }
            }
        }
        animator.startAnimation()
    }

    private func crossfade(_ viewer: PhotoViewerController, in context: any UIViewControllerContextTransitioning) {
        viewer.view.alpha = opening ? 0 : 1
        UIView.animate(withDuration: 0.25) {
            viewer.view.alpha = self.opening ? 1 : 0
            Self.setCardControls(of: viewer, hidden: self.opening)
        } completion: { _ in
            viewer.view.alpha = 1
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
}
