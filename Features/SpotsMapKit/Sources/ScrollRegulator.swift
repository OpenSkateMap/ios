import UIKit

@MainActor
protocol ScrollRegulator: AnyObject {
    func scrollView(_ scrollView: UIScrollView,
                    regulating proposed: CGPoint,
                    from previous: CGPoint,
                    pan: UIPanGestureRecognizer) -> CGPoint

    func scrollView(_ scrollView: UIScrollView, shouldDecelerate decelerates: Bool) -> Bool
}
