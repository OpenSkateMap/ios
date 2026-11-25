import AppLinkKit
import ComponentKit
import FactoryKit
import ImageKit
import os
import PinLayout
import SpotModelKit
import UIKit

// MARK: - PhotoViewerController

final class PhotoViewerController: UIViewController {

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "photo-viewer")
    private static let pageSpacing: CGFloat = 40
    private static let margin: CGFloat = 16
    private static let titleSpacing: CGFloat = 2
    /// From the system photo viewer's `PXSwipeDownSettings` on iOS 27, like the other swipe-down distances below.
    private static let scaleDownDistance: CGFloat = 200
    private static let resistanceDistance: CGFloat = 100
    private static let transitionDistance: CGFloat = 400
    private static let directionChange: CGFloat = 5
    private static let slowMotionRate: Float = 0.5
    private static let slowMotionPressDuration: TimeInterval = 0.3

    // MARK: Overridden Properties

    override var prefersStatusBarHidden: Bool {
        chromeHidden
    }

    /// Over a clip that fills the screen the status bar sits on the picture, not the background.
    override var preferredStatusBarStyle: UIStatusBarStyle {
        currentPage?.fillsScreen == true ? .lightContent : .default
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

    var clipPlayer: LoopingClipPlayer? {
        currentPage?.clipPlayer
    }

    /// The shown page's clip as it is now, so the photo flying between the card and the screen is the frame on screen.
    var clipFrame: UIImage? {
        currentPage?.clipFrame
    }

    var isPhotoHidden: Bool {
        get { pages.view.isHidden }
        set { pages.view.isHidden = newValue }
    }

    private var currentPage: PhotoPageViewController? {
        pages.viewControllers?.first as? PhotoPageViewController
    }

    private var chrome: [UIView] {
        [closeButton, titleView, counter, shareButton, clipControls]
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
    private let spotID: String
    private let spotTitle: String
    private let placeholders: [UIImage?]
    private let clipPlayback: ClipPlayback
    private let scale: CGFloat
    private let pages = UIPageViewController(
        transitionStyle: .scroll,
        navigationOrientation: .horizontal,
        options: [.interPageSpacing: pageSpacing],
    )
    private var pageCache = [Int: PhotoPageViewController]()
    private let closeButton = UIButton(configuration: .glass())
    private let shareButton = UIButton(configuration: .glass())
    private let titleView = PhotoViewerTitleView()
    private let counter = GlassCaption(font: .preferredFont(forTextStyle: .caption1, weight: .semibold))
    private let slowMotionCaption = GlassCaption(font: .preferredFont(forTextStyle: .caption1, weight: .semibold))
    private let clipControls = ClipControlsView()
    private var clipPosition: ClipPositionObservation?
    /// Which page's "has sound" answer is awaited, so a late one for a page left behind is dropped.
    private var soundRequest: Int?
    private var clipHasSound = false
    /// The viewer's sound choice, kept from clip to clip until it closes.
    private var isSoundOn = true
    private var isClosing = false
    private var resumesAfterScrub = false
    /// The player a hold slowed down, until the finger lifts.
    private var slowedPlayer: LoopingClipPlayer?
    /// Loading what Share sends; paging away or closing cancels it.
    private var sharing: Task<Void, Never>?
    private let singleTap = UITapGestureRecognizer()
    private let slowMotionPress = UILongPressGestureRecognizer()
    private let dismissPan = UIPanGestureRecognizer()
    private let transition: PhotoViewerTransition
    private let sourceView: (Int) -> UIImageView?
    private var panStart = CGPoint.zero
    private var directionMark: CGFloat = 0
    private var direction: CGFloat = 0
    /// Its own view: the zoom transition carries a view's alpha through a dismissal, not the root view's background color.
    private let backdropView = UIView()
    private var chromeHidden = false
    @LazyInjected(\.photoURLBuilder) private var urlBuilder
    @LazyInjected(\.imageLoader) private var imageLoader

    // MARK: Lifecycle

    init(photos: [GalleryPhoto],
         index: Int,
         spotID: String,
         spotTitle: String,
         placeholders: [UIImage?],
         scale: CGFloat,
         cardControls: [UIView],
         clipPlayback: ClipPlayback,
         sourceView: @escaping (Int) -> UIImageView?) {
        self.photos = photos
        self.spotID = spotID
        self.spotTitle = spotTitle
        self.clipPlayback = clipPlayback
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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        isClosing = true
        cancelSharing()
        endSlowMotion()
        applySound()
        // The card loops on, whatever was paused here.
        currentPage?.clipPlayer?.play()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        for page in pageCache.values {
            page.isActive = false
        }
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
        shareButton.pin
            .top(closeButton.frame.minY)
            .end(safe)
            .size(44)
            .marginEnd(Self.margin)
        let width = view.bounds.width - (safe.left + Self.margin + 44 + 12) * 2
        titleView.pin
            .top(closeButton.frame.minY)
            .hCenter()
            .maxWidth(width)
            .sizeToFit(.widthFlexible)
        if titleView.isHidden {
            counter.pin
                .vCenter(to: closeButton.edge.vCenter)
                .hCenter()
                .maxWidth(width)
                .sizeToFit(.widthFlexible)
        } else {
            counter.pin
                .below(of: titleView)
                .hCenter()
                .maxWidth(width)
                .sizeToFit(.widthFlexible)
                .marginTop(Self.titleSpacing)
        }
        layoutSlowMotionCaption(width: width)
        clipControls.pin
            .bottom(safe.bottom + 12)
            .hCenter()
            .width(min(view.bounds.width - safe.left - safe.right - Self.margin * 2, 500))
            .height(ClipControlsView.height)
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
        shareButton.configuration = .glassIcon("square.and.arrow.up", textStyle: .body, scale: .medium)
        shareButton.accessibilityLabel = SpotDetailKitStrings.PhotoViewer.A11y.share
        shareButton.addAction(UIAction { [weak self] _ in self?.share() }, for: .primaryActionTriggered)
        for control in chrome {
            view.addSubview(control)
        }
        slowMotionCaption.text = SpotDetailKitStrings.PhotoViewer.slowMotion(Double(Self.slowMotionRate).formatted())
        slowMotionCaption.isHidden = true
        slowMotionCaption.alpha = 0
        view.addSubview(slowMotionCaption)
        setupClipControls()
    }

    private func layoutSlowMotionCaption(width: CGFloat) {
        guard let above = [counter, titleView].first(where: { !$0.isHidden }) else {
            slowMotionCaption.pin
                .vCenter(to: closeButton.edge.vCenter)
                .hCenter()
                .maxWidth(width)
                .sizeToFit(.widthFlexible)
            return
        }
        slowMotionCaption.pin
            .below(of: above)
            .hCenter()
            .maxWidth(width)
            .sizeToFit(.widthFlexible)
            .marginTop(Self.titleSpacing)
    }

    private func setupClipControls() {
        clipControls.isHidden = true
        clipControls.onPlayPause = { [weak self] in
            guard let player = self?.currentPage?.clipPlayer else {
                return
            }
            if player.isPlaying {
                player.pause()
            } else {
                player.play()
            }
            self?.clipControls.show(isPlaying: player.isPlaying)
        }
        clipControls.onScrubStart = { [weak self] in
            guard let self, let player = currentPage?.clipPlayer else {
                return
            }
            resumesAfterScrub = player.isPlaying
            player.pause()
        }
        clipControls.onScrub = { [weak self] seconds in
            self?.currentPage?.clipPlayer?.seek(to: seconds)
        }
        clipControls.onScrubEnd = { [weak self] in
            guard let self, resumesAfterScrub else {
                return
            }
            resumesAfterScrub = false
            currentPage?.clipPlayer?.play()
        }
        clipControls.onSoundToggle = { [weak self] in
            guard let self else {
                return
            }
            isSoundOn.toggle()
            applySound()
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
        singleTap.delegate = self
        view.addGestureRecognizer(singleTap)
        slowMotionPress.minimumPressDuration = Self.slowMotionPressDuration
        slowMotionPress.addTarget(self, action: #selector(slowMotionPressed(_:)))
        slowMotionPress.delegate = self
        view.addGestureRecognizer(slowMotionPress)
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
            clipPlayback: clipPlayback,
        )
        page.onZoomIn = { [weak self] in self?.setChromeHidden(true) }
        page.onLayoutChange = { [weak self] in self?.setNeedsStatusBarAppearanceUpdate() }
        singleTap.require(toFail: page.doubleTap)
        page.panGesture.require(toFail: dismissPan)
        pageCache[index] = page
        return page
    }

    private func showPage() {
        cancelSharing()
        endSlowMotion()
        shareButton.isHidden = photos[index].key == nil
        counter.text = photos.count > 1 ? SpotDetailKitStrings.PhotoViewer.counter(index + 1, photos.count) : nil
        let photo = photos[index]
        titleView.show(
            name: photo.credit,
            credit: photo.credit.map { photo.clip == nil
                ? SpotDetailKitStrings.PhotoViewer.credit($0)
                : SpotDetailKitStrings.PhotoViewer.videoCredit($0)
            },
            addedAt: photo.addedAt,
        )
        for neighbour in [index - 1, index + 1] {
            page(at: neighbour)?.loadViewIfNeeded()
        }
        for (pageIndex, page) in pageCache {
            page.isActive = pageIndex == index
        }
        showClipControls()
        setNeedsStatusBarAppearanceUpdate()
        view.setNeedsLayout()
    }

    private func showClipControls() {
        clipHasSound = false
        soundRequest = nil
        guard let clip = photos[index].clip, let player = currentPage?.clipPlayer else {
            clipPosition = nil
            clipControls.isHidden = true
            applySound()
            return
        }
        clipControls.isHidden = false
        clipControls.show(duration: Double(clip.durationMs) / 1000)
        clipControls.show(isPlaying: player.isPlaying)
        clipPosition = player.observePosition(every: 1.0 / 30) { [weak self] seconds in
            self?.clipControls.show(position: seconds)
        }
        // New players start muted; the audio stays until the answer, so paging between clips with sound keeps it.
        clipControls.show(sound: .none)
        let request = index
        soundRequest = request
        Task { [weak self] in
            let hasSound = await player.hasSound()
            guard let self, soundRequest == request else {
                return
            }
            clipHasSound = hasSound
            applySound()
        }
    }

    /// Sound plays only for a clip that has some, with the speaker on and the viewer not closing. The audio, once
    /// taken, stays until the viewer closes, and goes back once no clip is playing.
    private func applySound() {
        let plays = clipHasSound && isSoundOn && !isClosing
        if plays {
            ClipSound.takeAudio()
        }
        currentPage?.clipPlayer?.isMuted = !plays
        if isClosing {
            ClipSound.handBackAudio()
        }
        clipControls.show(sound: clipHasSound ? (isSoundOn ? .on : .off) : .none)
    }

    private func share() {
        guard sharing == nil else {
            return
        }
        let photo = photos[index]
        sharing = Task { [weak self] in
            do {
                guard let media = try await self?.media(for: photo) else {
                    return
                }
                guard let self, !Task.isCancelled else {
                    media.discard()
                    return
                }
                finishSharing()
                presentShareSheet(with: media, of: photo)
            } catch {
                guard let self, !Task.isCancelled else {
                    return
                }
                finishSharing()
                Self.logger.notice("A page couldn't be shared: \(String(describing: error), privacy: .public)")
                ToastView.showFailure(photo.clip == nil
                    ? SpotDetailKitStrings.PhotoViewer.Share.photoFailed
                    : SpotDetailKitStrings.PhotoViewer.Share.videoFailed)
            }
        }
        shareButton.configuration?.showsActivityIndicator = true
    }

    /// A clip as its file, a photo at its largest variant (the page's own request, so usually from the cache).
    private func media(for photo: GalleryPhoto) async throws -> PhotoViewerShare.Media {
        if let clip = photo.clip, let url = urlBuilder.clipURL(for: clip.key) {
            return try await .clip(PhotoViewerShare.downloadClip(from: url, named: PhotoViewerShare.fileName(for: spotTitle)))
        }
        guard let key = photo.key, let url = urlBuilder.url(for: key, size: .fullScreen, scale: scale) else {
            throw URLError(.unsupportedURL)
        }
        return try await .image(imageLoader.photo(url, .fullScreen))
    }

    private func presentShareSheet(with media: PhotoViewerShare.Media, of photo: GalleryPhoto) {
        let text = PhotoViewerShare.text(spot: spotTitle, credit: photo.credit, isClip: photo.clip != nil)
        let link = SpotLinkItem(url: AppLink.spot(id: spotID).url, title: spotTitle, image: media.image ?? currentPage?.image)
        let activity = UIActivityViewController(activityItems: [media.item, text, link], applicationActivities: nil)
        activity.completionWithItemsHandler = { _, _, _, _ in media.discard() }
        activity.popoverPresentationController?.sourceItem = shareButton
        present(activity, animated: true)
    }

    private func finishSharing() {
        sharing = nil
        shareButton.configuration?.showsActivityIndicator = false
    }

    private func cancelSharing() {
        sharing?.cancel()
        finishSharing()
    }

    private func endSlowMotion() {
        slowedPlayer?.rate = 1
        slowedPlayer = nil
        setSlowMotionCaptionShown(false)
    }

    private func setSlowMotionCaptionShown(_ shown: Bool) {
        guard shown != (slowMotionCaption.alpha == 1) else {
            return
        }
        slowMotionCaption.isHidden = false
        UIView.animate(withDuration: 0.2) {
            self.slowMotionCaption.alpha = shown ? 1 : 0
        } completion: { _ in
            self.slowMotionCaption.isHidden = self.slowedPlayer == nil
        }
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
    private func slowMotionPressed(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            guard let player = currentPage?.clipPlayer else {
                return
            }
            player.rate = Self.slowMotionRate
            slowedPlayer = player
            UIImpactFeedbackGenerator(style: .light, view: view).impactOccurred(at: recognizer.location(in: view))
            setSlowMotionCaptionShown(true)

        case .ended, .cancelled, .failed:
            endSlowMotion()

        default:
            break
        }
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
    /// The clip's controls take their own touches: tapping between them doesn't hide them, and scrubbing doesn't close.
    /// A hold slows the clip only on the page, never on a button.
    func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if touch.view?.isDescendant(of: clipControls) == true {
            return false
        }
        return recognizer !== slowMotionPress || touch.view?.isDescendant(of: pages.view) == true
    }

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        if recognizer === slowMotionPress {
            return currentPage?.clipPlayer?.isPlaying == true
        }
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

    private static let insets = UIEdgeInsets(top: 4, left: 12, bottom: 4, right: 12)

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
