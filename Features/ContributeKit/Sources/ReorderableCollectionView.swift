import UIKit

/// A collection view whose items lift with a long press and follow the finger: the items they pass make room at once,
/// the copy in hand takes the size of the place it's over, and the view scrolls while one is held near an end. The
/// delegate owns the order, moves the items and makes the copy.
final class ReorderableCollectionView: UICollectionView {

    // MARK: Types

    private struct Lift {
        var indexPath: IndexPath
        let view: UIView
        /// From the finger to the copy's centre, as a share of its size, so the copy neither jumps under the finger
        /// nor leaves it as it grows or shrinks.
        let grip: CGPoint
        var location: CGPoint
    }

    // MARK: Static Properties

    /// The fastest autoscroll, in points per 60 Hz frame, with the item at the very end.
    private static let maxScrollStep: CGFloat = 10
    /// How far outside the view a held item still moves the others.
    private static let reach: CGFloat = 24
    private static let liftScale: CGFloat = 1.08

    // MARK: Computed Properties

    var isReordering: Bool {
        lift != nil
    }

    var pressDuration: TimeInterval {
        get { longPress.minimumPressDuration }
        set { longPress.minimumPressDuration = newValue }
    }

    private var isHorizontal: Bool {
        (collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection == .horizontal
    }

    // MARK: Properties

    weak var reorderDelegate: any ReorderableCollectionViewDelegate?
    var scrollThreshold: CGFloat = 40

    private var lift: Lift?
    private var displayLink: CADisplayLink?
    private lazy var longPress = UILongPressGestureRecognizer(target: self, action: #selector(longPressed(_:)))

    // MARK: Lifecycle

    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)

        addGestureRecognizer(longPress)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        if lift != nil {
            hideLiftedItem()
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            cancelReordering()
        }
    }

    // MARK: Functions

    /// Ends a drag under way as if the finger lifted where it is.
    private func cancelReordering() {
        longPress.isEnabled = false
        longPress.isEnabled = true
    }

    @objc
    private func longPressed(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began: begin(at: location)
        case .changed: drag(to: location)
        case .ended, .cancelled, .failed: end()
        case .possible: break
        @unknown default: end()
        }
    }

    private func begin(at location: CGPoint) {
        guard let indexPath = indexPathForItem(at: location),
              reorderDelegate?.collectionView(self, canMoveItemAt: indexPath) ?? false,
              let cell = cellForItem(at: indexPath),
              let view = reorderDelegate?.collectionView(self, liftedViewForItemAt: indexPath) else {
            return
        }
        view.frame = cell.frame
        view.isUserInteractionEnabled = false
        view.layer.zPosition = 1000
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOffset = CGSize(width: 0, height: 8)
        view.layer.shadowRadius = 12
        addSubview(view)
        lift = Lift(
            indexPath: indexPath,
            view: view,
            grip: CGPoint(
                x: (cell.center.x - location.x) / cell.bounds.width,
                y: (cell.center.y - location.y) / cell.bounds.height,
            ),
            location: location,
        )
        hideLiftedItem()
        UIImpactFeedbackGenerator(style: .medium, view: self).impactOccurred(at: location)
        let scale = UIAccessibility.isReduceMotionEnabled ? 1 : Self.liftScale
        UIView.animate(springDuration: 0.3, bounce: 0.2) {
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
            view.layer.shadowOpacity = 0.25
        }
        reorderDelegate?.collectionView(self, didLiftItemAt: indexPath)
    }

    private func drag(to location: CGPoint) {
        guard var lift else {
            return
        }
        lift.location = location
        self.lift = lift
        follow()
        reorder()
        updateAutoscroll()
    }

    private func end() {
        guard let lift else {
            return
        }
        stopAutoscroll()
        self.lift = nil
        let place = layoutAttributesForItem(at: lift.indexPath)?.frame
        reorderDelegate?.collectionView(self, didEndReorderingItemAt: lift.indexPath)
        // The item's own cell stays empty until its copy has landed.
        UIView.animate(springDuration: 0.35, bounce: 0.1) {
            if let place {
                lift.view.transform = .identity
                lift.view.bounds.size = place.size
                lift.view.center = CGPoint(x: place.midX, y: place.midY)
                lift.view.layer.shadowOpacity = 0
                lift.view.layoutIfNeeded()
            } else {
                lift.view.alpha = 0
            }
        } completion: { [weak self] _ in
            lift.view.removeFromSuperview()
            if self?.lift == nil {
                self?.hideLiftedItem()
            }
        }
    }

    private func follow() {
        guard let lift else {
            return
        }
        let size = lift.view.bounds.size
        lift.view.center = CGPoint(x: lift.location.x + lift.grip.x * size.width, y: lift.location.y + lift.grip.y * size.height)
    }

    /// Moves the held item to the place under the finger, while the finger is over the items or just beside them, and
    /// lets the copy take that place's size.
    private func reorder() {
        guard let lift, bounds.insetBy(dx: -Self.reach, dy: -Self.reach).contains(lift.location) else {
            return
        }
        let point = CGPoint(
            x: min(max(lift.location.x, bounds.minX + 1), bounds.maxX - 1),
            y: min(max(lift.location.y, bounds.minY + 1), bounds.maxY - 1),
        )
        guard let destination = indexPathForItem(at: point), destination != lift.indexPath,
              reorderDelegate?.collectionView(self, canMoveItemAt: destination) ?? false else {
            return
        }
        reorderDelegate?.collectionView(self, moveItemAt: lift.indexPath, to: destination)
        self.lift?.indexPath = destination
        hideLiftedItem()
        guard let size = layoutAttributesForItem(at: destination)?.size, size != lift.view.bounds.size else {
            return
        }
        UIView.animate(springDuration: 0.35, bounce: 0.1) {
            lift.view.bounds.size = size
            self.follow()
            lift.view.layoutIfNeeded()
        }
    }

    /// The held item's own cell stays empty while its copy is up. Its content view, not the cell: a layout pass sets
    /// every cell's alpha from its attributes, which showed the cell again while the copy was still on its way.
    private func hideLiftedItem() {
        for cell in visibleCells {
            cell.contentView.alpha = lift != nil && indexPath(for: cell) == lift?.indexPath ? 0 : 1
        }
    }

    /// -1...1: how hard, and which way, a held item near an end scrolls the view.
    private func scrollWeight(at location: CGPoint) -> CGFloat {
        guard isScrollEnabled else {
            return 0
        }
        let across = isHorizontal ? location.y - bounds.midY : location.x - bounds.midX
        let half = (isHorizontal ? bounds.height : bounds.width) / 2
        guard abs(across) <= half + Self.reach else {
            return 0
        }
        let along = isHorizontal ? location.x - bounds.minX : location.y - bounds.minY
        let length = isHorizontal ? bounds.width : bounds.height
        if along < scrollThreshold {
            return -min((scrollThreshold - along) / scrollThreshold, 1)
        }
        if along > length - scrollThreshold {
            return min((along - length + scrollThreshold) / scrollThreshold, 1)
        }
        return 0
    }

    private func updateAutoscroll() {
        guard let lift, scrollWeight(at: lift.location) != 0 else {
            return stopAutoscroll()
        }
        guard displayLink == nil else {
            return
        }
        let link = CADisplayLink(target: self, selector: #selector(autoscroll(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopAutoscroll() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc
    private func autoscroll(_ link: CADisplayLink) {
        guard var lift else {
            return stopAutoscroll()
        }
        let frames = CGFloat((link.targetTimestamp - link.timestamp) * 60)
        let step = scrollWeight(at: lift.location) * Self.maxScrollStep * frames
        let insets = adjustedContentInset
        var offset = contentOffset
        if isHorizontal {
            offset.x = min(max(offset.x + step, -insets.left), max(contentSize.width + insets.right - bounds.width, -insets.left))
        } else {
            offset.y = min(
                max(offset.y + step, -insets.top),
                max(contentSize.height + insets.bottom - bounds.height, -insets.top),
            )
        }
        guard offset != contentOffset else {
            return stopAutoscroll()
        }
        // The finger stays put on screen while the content moves under it.
        lift.location.x += offset.x - contentOffset.x
        lift.location.y += offset.y - contentOffset.y
        contentOffset = offset
        self.lift = lift
        follow()
        reorder()
    }
}
