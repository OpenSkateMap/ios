import ComponentKit
import FactoryKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

// MARK: - PhotoPageViewController

final class PhotoPageViewController: UIViewController {

    // MARK: Static Properties

    private static let maximumZoomScale: CGFloat = 4
    private static let doubleTapZoomScale: CGFloat = 2.5
    /// A clip fills the screen when that hides at most this much of it: a 9:16 clip on any iPhone held upright
    /// (19.5:9 hides 18%), not a 3:4 one (39%).
    private static let clipFillCrop: CGFloat = 0.2

    // MARK: Computed Properties

    var isZoomedIn: Bool {
        scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
    }

    var image: UIImage? {
        imageView.image
    }

    var clipFrame: UIImage? {
        clipURL.flatMap(clipPlayback.currentFrame(of:))
    }

    /// A clip shown edge to edge, cropped rather than letterboxed.
    var fillsScreen: Bool {
        guard photo.clip != nil, let image = imageView.image, image.size.height > 0 else {
            return false
        }
        let bounds = scrollView.bounds.size
        guard bounds.height > 0 else {
            return false
        }
        let ratio = (image.size.width / image.size.height) / (bounds.width / bounds.height)
        return 1 - min(ratio, 1 / ratio) <= Self.clipFillCrop
    }

    var clipPlayer: LoopingClipPlayer? {
        clipURL.flatMap(clipPlayback.player(of:))
    }

    var panGesture: UIPanGestureRecognizer {
        scrollView.panGestureRecognizer
    }

    private var clipURL: URL? {
        photo.clip.flatMap { urlBuilder.clipURL(for: $0.key) }
    }

    private var fillScale: CGFloat {
        let bounds = scrollView.bounds.size
        let fitted = fittedSize()
        guard fitted.width > 0, fitted.height > 0 else {
            return 1
        }
        return max(bounds.width / fitted.width, bounds.height / fitted.height)
    }

    // MARK: Properties

    let index: Int
    let doubleTap = UITapGestureRecognizer()
    var onZoomIn: (() -> Void)?
    /// Whether the page fills the screen may have changed: its photo arrived.
    var onLayoutChange: (() -> Void)?
    var isActive = false {
        didSet {
            if isActive != oldValue {
                renderClip()
            }
        }
    }

    private let photo: GalleryPhoto
    private let placeholder: UIImage?
    private let scale: CGFloat
    private let scrollView = UIScrollView().softEdges()
    private let imageView = ObservedImageView()
    private let loader = PhotoLoader()
    private let clipPlayback: ClipPlayback
    private let clipView = ClipLayerView(revealDuration: 0.2)
    @LazyInjected(\.photoURLBuilder) private var urlBuilder

    // MARK: Lifecycle

    init(photo: GalleryPhoto, index: Int, placeholder: UIImage?, scale: CGFloat, clipPlayback: ClipPlayback) {
        self.photo = photo
        self.index = index
        self.placeholder = placeholder
        self.scale = scale
        self.clipPlayback = clipPlayback
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupGestures()
        loader.show(
            key: photo.key,
            thumbhash: photo.thumbhash,
            size: .fullScreen,
            scale: scale,
            placeholder: placeholder,
            in: imageView,
        )
        renderClip()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if scrollView.frame != view.bounds {
            scrollView.setZoomScale(1, animated: false)
            scrollView.pin
                .all()
        }
        if scrollView.zoomScale == 1 {
            let size = fittedSize()
            // swiftlint:disable pinlayout_left_right - zoomed content lives in the scroll view's own coordinates
            imageView.pin
                .top()
                .left()
                .width(size.width)
                .height(size.height)
            // swiftlint:enable pinlayout_left_right
            scrollView.contentSize = size
            scrollView.maximumZoomScale = max(Self.maximumZoomScale, fillScale)
        }
        clipView.pin
            .all()
        centerPhoto()
    }

    // MARK: Functions

    func photoFrame(in space: UIView) -> CGRect? {
        view.layoutIfNeeded()
        guard imageView.image != nil, !imageView.bounds.isEmpty else {
            return nil
        }
        return imageView.convert(imageView.bounds, to: space)
    }

    func resetZoom() {
        scrollView.setZoomScale(1, animated: false)
    }

    private func setupViews() {
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = Self.maximumZoomScale
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.decelerationRate = .fast
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.accessibilityIgnoresInvertColors = true
        imageView.onImageChange = { [weak self] in
            self?.view.setNeedsLayout()
            self?.onLayoutChange?()
        }
        // Inside the photo, so it zooms with it and leaves with it when the photo flies back to the card.
        imageView.addSubview(clipView)
        scrollView.addSubview(imageView)
        view.addSubview(scrollView)
    }

    private func setupGestures() {
        doubleTap.numberOfTapsRequired = 2
        doubleTap.addTarget(self, action: #selector(doubleTapped))
        scrollView.addGestureRecognizer(doubleTap)
    }

    private func renderClip() {
        guard isViewLoaded else {
            return
        }
        if isActive, let url = clipURL {
            clipPlayback.show(url, in: clipView)
        } else {
            clipPlayback.release(clipView)
        }
    }

    private func fittedSize() -> CGSize {
        let bounds = scrollView.bounds.size
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else {
            return .zero
        }
        if fillsScreen {
            return bounds
        }
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        return CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
    }

    private func centerPhoto() {
        let bounds = scrollView.bounds.size
        let content = imageView.frame.size
        let horizontal = max((bounds.width - content.width) / 2, 0)
        let vertical = max((bounds.height - content.height) / 2, 0)
        scrollView.contentInset = UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}

// MARK: Actions

extension PhotoPageViewController {
    @objc
    private func doubleTapped(_ recognizer: UITapGestureRecognizer) {
        if isZoomedIn {
            scrollView.setZoomScale(1, animated: true)
            return
        }
        onZoomIn?()
        let point = recognizer.location(in: imageView)
        let scale = min(fillScale > 1.25 ? fillScale : Self.doubleTapZoomScale, scrollView.maximumZoomScale)
        let size = CGSize(width: scrollView.bounds.width / scale, height: scrollView.bounds.height / scale)
        scrollView.zoom(
            to: CGRect(origin: CGPoint(x: point.x - size.width / 2, y: point.y - size.height / 2), size: size),
            animated: true,
        )
    }
}

// MARK: UIScrollViewDelegate

extension PhotoPageViewController: UIScrollViewDelegate {
    func viewForZooming(in _: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewWillBeginZooming(_: UIScrollView, with _: UIView?) {
        onZoomIn?()
    }

    func scrollViewDidZoom(_: UIScrollView) {
        centerPhoto()
    }
}

// MARK: - ObservedImageView

private final class ObservedImageView: UIImageView {

    // MARK: Overridden Properties

    override var image: UIImage? {
        didSet {
            onImageChange?()
        }
    }

    // MARK: Properties

    var onImageChange: (() -> Void)?
}
