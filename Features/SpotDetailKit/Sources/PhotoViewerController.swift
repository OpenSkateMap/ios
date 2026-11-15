import ComponentKit
import PinLayout
import UIKit

// MARK: - PhotoViewerController

final class PhotoViewerController: UIViewController {

    // MARK: Static Properties

    private static let pageSpacing: CGFloat = 40
    private static let margin: CGFloat = 16
    /// From the system photo viewer's `PXSwipeDownSettings` on iOS 27, like the other swipe-down distances below.
    private static let scaleDownDistance: CGFloat = 200
    private static let resistanceDistance: CGFloat = 100
    private static let transitionDistance: CGFloat = 400
    private static let directionChange: CGFloat = 5

    // MARK: Overridden Properties

    override var prefersStatusBarHidden: Bool {
        chromeHidden
    }

    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation {
        .fade
    }

    // MARK: Computed Properties

    var isZoomedIn: Bool {
        currentPage?.isZoomedIn ?? false
    }

    var photoFrame: CGRect? {
        currentPage?.photoFrame(in: view)
    }

    var photoImage: UIImage? {
        currentPage?.image
    }

    var isPhotoHidden: Bool {
        get { pages.view.isHidden }
        set { pages.view.isHidden = newValue }
    }

    private var currentPage: PhotoPageViewController? {
        pages.viewControllers?.first as? PhotoPageViewController
    }

    private var chrome: [UIView] {
        [closeButton, counter, credit]
    }

    private var backdrop: UIColor {
        chromeHidden ? .black : .systemBackground
    }

    // MARK: Properties

    var onPageChange: ((Int) -> Void)?
    /// Controls on the card (the star): they leave with the photo and come back as it lands.
    let cardControls: [UIView]
    private(set) var index: Int
    private(set) var releaseVelocity = CGPoint.zero

    private let photos: [GalleryPhoto]
    private let placeholders: [UIImage?]
    private let scale: CGFloat
    private let pages = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal,
        options: [.interPageSpacing: pageSpacing],
    )
    private var pageCache = [Int: PhotoPageViewController]()
    private let closeButton = UIButton(configuration: .glass())
    private let counter = GlassCaption(font: .preferredFont(forTextStyle: .subheadline, weight: .semibold))
    private let credit = GlassCaption(font: .preferredFont(forTextStyle: .footnote))
    private let singleTap = UITapGestureRecognizer()
    private let dismissPan = UIPanGestureRecognizer()
    private let transition: PhotoViewerTransition
    private let sourceView: (Int) -> UIImageView?
    private var panStart = CGPoint.zero
    private var directionMark: CGFloat = 0
    private var direction: CGFloat = 0
    /// Its own view: the zoom transition carries a view's alpha through a dismissal, not the root view's background color.
    private let backdropView = UIView()
    private var chromeHidden = false

    // MARK: Lifecycle

    init(photos: [GalleryPhoto],
         index: Int,
         placeholders: [UIImage?],
         scale: CGFloat,
         cardControls: [UIView],
         sourceView: @escaping (Int) -> UIImageView?) {
        self.photos = photos
        self.cardControls = cardControls
        self.index = index
        self.placeholders = placeholders
        self.scale = scale
        self.sourceView = sourceView
        transition = PhotoViewerTransition(sourceView: sourceView)
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalPresentationCapturesStatusBarAppearance = true
        transitioningDelegate = transition
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupPages()
        setupGestures()
        showPage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        backdropView.pin
            .all()
        pages.view.pin
            .all()
        let safe = view.pin.safeArea
        closeButton.pin
            .top(safe.top + 8)
            .start(safe)
            .size(44)
            .marginStart(Self.margin)
        let width = view.bounds.width - (safe.left + Self.margin + 44 + 12) * 2
        counter.pin
            .vCenter(to: closeButton.edge.vCenter)
            .hCenter()
            .maxWidth(width)
            .sizeToFit(.widthFlexible)
        credit.pin
            .bottom(safe.bottom + 12)
            .hCenter()
            .maxWidth(view.bounds.width - safe.left - safe.right - Self.margin * 2)
            .sizeToFit(.widthFlexible)
    }

    // MARK: Functions

    func setSurroundingsVisible(_ visible: Bool) {
        setFaded(!visible)
    }

    private func setupViews() {
        view.backgroundColor = .clear
        backdropView.backgroundColor = backdrop
        view.addSubview(backdropView)
        view.accessibilityViewIsModal = true
        closeButton.configuration = .glassIcon("xmark", textStyle: .body, scale: .medium)
        closeButton.accessibilityLabel = SpotDetailKitStrings.PhotoViewer.A11y.close
        closeButton.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .primaryActionTriggered)
        for control in chrome {
            view.addSubview(control)
        }
    }

    private func setupPages() {
        pages.dataSource = self
        pages.delegate = self
        addChild(pages)
        view.insertSubview(pages.view, aboveSubview: backdropView)
        pages.didMove(toParent: self)
        if let page = page(at: index) {
            pages.setViewControllers([page], direction: .forward, animated: false)
        }
    }

    private func setupGestures() {
        singleTap.addTarget(self, action: #selector(toggleChrome))
        view.addGestureRecognizer(singleTap)
        dismissPan.addTarget(self, action: #selector(dismissPanned(_:)))
        dismissPan.delegate = self
        view.addGestureRecognizer(dismissPan)
        for case let pager as UIScrollView in pages.view.subviews {
            pager.panGestureRecognizer.require(toFail: dismissPan)
        }
    }

    private func page(at index: Int) -> PhotoPageViewController? {
        guard photos.indices.contains(index) else {
            return nil
        }
        if let page = pageCache[index] {
            return page
        }
        let page = PhotoPageViewController(
            photo: photos[index],
            index: index,
            placeholder: placeholders.indices.contains(index) ? placeholders[index] : nil,
            scale: scale,
        )
        page.onZoomIn = { [weak self] in self?.setChromeHidden(true) }
        singleTap.require(toFail: page.doubleTap)
        page.panGesture.require(toFail: dismissPan)
        pageCache[index] = page
        return page
    }

    private func showPage() {
        counter.text = photos.count > 1 ? SpotDetailKitStrings.PhotoViewer.counter(index + 1, photos.count) : nil
        credit.text = photos[index].credit.map { SpotDetailKitStrings.PhotoViewer.credit($0) }
        for neighbour in [index - 1, index + 1] {
            page(at: neighbour)?.loadViewIfNeeded()
        }
        view.setNeedsLayout()
    }

    private func setChromeHidden(_ hidden: Bool) {
        guard hidden != chromeHidden else {
            return
        }
        chromeHidden = hidden
        UIView.animate(withDuration: UINavigationController.hideShowBarDuration) {
            self.backdropView.backgroundColor = self.backdrop
            self.setFaded(false)
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }

    private func setFaded(_ faded: Bool) {
        setBackdropFaded(faded)
        setChromeFaded(faded)
    }

    private func swipeDownTransform(for translation: CGPoint, around point: CGPoint, of page: UIView) -> CGAffineTransform {
        let resisted = { (value: CGFloat) in Self.resistanceDistance * log(1 + abs(value) / Self.resistanceDistance) * (value < 0
                ? -1
                : 1) }
        let offset = CGPoint(x: resisted(translation.x), y: translation.y >= 0 ? translation.y : resisted(translation.y))
        let scale = translation.y > 0 ? 0.5 + 0.5 * cos(atan(translation.y / Self.scaleDownDistance)) : 1
        let center = CGPoint(x: page.bounds.midX, y: page.bounds.midY)
        return CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: scale,
            tx: (1 - scale) * (point.x - center.x) + offset.x,
            ty: (1 - scale) * (point.y - center.y) + offset.y,
        )
    }

    private func setBackdropFaded(_ faded: Bool) {
        backdropView.alpha = faded ? 0 : 1
    }

    private func settleBack(_ page: UIView) {
        let animator = UIViewPropertyAnimator(duration: 0.3, dampingRatio: 1) {
            page.transform = .identity
            self.setFaded(false)
        }
        animator.addCompletion { [weak self] _ in
            guard let self else {
                return
            }
            sourceView(index)?.isHidden = false
        }
        animator.startAnimation()
    }

    private func setChromeFaded(_ faded: Bool) {
        for control in chrome {
            control.alpha = faded || chromeHidden ? 0 : 1
        }
    }
}

// MARK: Actions

extension PhotoViewerController {
    @objc
    private func toggleChrome() {
        setChromeHidden(!chromeHidden)
    }

    @objc
    private func dismissPanned(_ recognizer: UIPanGestureRecognizer) {
        guard let page = currentPage?.view else {
            return
        }
        let translation = recognizer.translation(in: view)
        switch recognizer.state {
        case .began:
            panStart = recognizer.location(in: page)
            directionMark = translation.y
            direction = 0
            sourceView(index)?.isHidden = true
            UIView.animate(withDuration: 0.2) { self.setChromeFaded(true) }

        case .changed:
            if abs(translation.y - directionMark) >= Self.directionChange {
                direction = translation.y - directionMark
                directionMark = translation.y
            }
            page.transform = swipeDownTransform(for: translation, around: panStart, of: page)
            backdropView.alpha = 1 - min(max(translation.y, 0) / Self.transitionDistance, 1)

        case .ended, .cancelled, .failed:
            if recognizer.state == .ended, direction >= 0, translation.y > 0 {
                releaseVelocity = recognizer.velocity(in: view)
                dismiss(animated: true)
            } else {
                settleBack(page)
            }

        default:
            break
        }
    }

    override func accessibilityPerformEscape() -> Bool {
        dismiss(animated: true)
        return true
    }
}

// MARK: UIGestureRecognizerDelegate

extension PhotoViewerController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard recognizer === dismissPan else {
            return true
        }
        let velocity = dismissPan.velocity(in: view)
        return !isZoomedIn && velocity.y > 0 && velocity.y > abs(velocity.x)
    }
}

// MARK: UIPageViewControllerDataSource

extension PhotoViewerController: UIPageViewControllerDataSource {
    func pageViewController(_: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        (viewController as? PhotoPageViewController).flatMap { page(at: $0.index - 1) }
    }

    func pageViewController(_: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        (viewController as? PhotoPageViewController).flatMap { page(at: $0.index + 1) }
    }
}

// MARK: UIPageViewControllerDelegate

extension PhotoViewerController: UIPageViewControllerDelegate {
    func pageViewController(_: UIPageViewController,
                            didFinishAnimating _: Bool,
                            previousViewControllers: [UIViewController],
                            transitionCompleted completed: Bool) {
        guard completed, let page = currentPage else {
            return
        }
        for previous in previousViewControllers where previous !== page {
            (previous as? PhotoPageViewController)?.resetZoom()
        }
        index = page.index
        pageCache = pageCache.filter { abs($0.key - index) <= 1 }
        showPage()
        onPageChange?(index)
    }
}

// MARK: - GlassCaption

private final class GlassCaption: UIVisualEffectView {

    // MARK: Static Properties

    private static let insets = UIEdgeInsets(top: 7, left: 14, bottom: 7, right: 14)

    // MARK: Computed Properties

    var text: String? {
        get { label.text }
        set {
            label.text = newValue
            accessibilityLabel = newValue
            isHidden = newValue == nil
        }
    }

    // MARK: Properties

    private let label = Label()

    // MARK: Lifecycle

    init(font: UIFont) {
        super.init(effect: UIGlassEffect())

        cornerConfiguration = .capsule()
        isUserInteractionEnabled = false
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.isAccessibilityElement = false
        contentView.addSubview(label)
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        label.pin
            .all(Self.insets)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let insets = Self.insets
        let text = label.sizeThatFits(CGSize(width: max(size.width - insets.left - insets.right, 0), height: size.height))
        return CGSize(
            width: ceil(text.width) + insets.left + insets.right,
            height: ceil(text.height) + insets.top + insets.bottom,
        )
    }
}
