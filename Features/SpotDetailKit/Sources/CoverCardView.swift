import ComponentKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

// MARK: - CoverCardView

final class CoverCardView: UIView {

    // MARK: Static Properties

    private static let pageGap: CGFloat = 12

    // MARK: Computed Properties

    var image: UIImage? {
        pageViews.first?.image
    }

    private(set) var currentPage: Int {
        get { pageControl.currentPage }
        set {
            pageControl.currentPage = newValue
            updateAccessibilityValue()
        }
    }

    // MARK: Properties

    var preferredHeight: CGFloat = 220
    var onOpen: ((Int) -> Void)?
    private(set) var pages = [GalleryPhoto]()

    private let fallback = CAGradientLayer()
    private let glyphView = UIImageView()
    private let pager = UIScrollView().softEdges()
    private let pageControl = UIPageControl()
    private var slots = [UIView]()
    private var pageViews = [UIImageView]()
    private var loaders = [PhotoLoader]()
    private var spotID: String?
    private var scale: CGFloat = 3
    private var pageWidth: CGFloat = 0

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true
        layer.cornerRadius = SpotPageView.cardCornerRadius
        layer.cornerCurve = .continuous
        layer.addSublayer(fallback)
        glyphView.tintColor = UIColor.white.withAlphaComponent(0.9)
        glyphView.contentMode = .center
        glyphView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 34, weight: .semibold)
        pager.isPagingEnabled = true
        pager.clipsToBounds = false
        pager.showsHorizontalScrollIndicator = false
        pager.alwaysBounceHorizontal = false
        pager.delegate = self
        pager.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        pageControl.hidesForSinglePage = true
        pageControl.overrideUserInterfaceStyle = .dark
        pageControl.backgroundStyle = .automatic
        pageControl.addAction(UIAction { [weak self] _ in
            guard let self else {
                return
            }
            show(page: pageControl.currentPage, animated: pageControl.interactionState != .continuous)
        }, for: .valueChanged)
        addSubview(glyphView)
        addSubview(pager)
        addSubview(pageControl)
        isAccessibilityElement = true
        accessibilityTraits = .image
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fallback.frame = bounds
        CATransaction.commit()
        glyphView.pin
            .all()
        let stride = bounds.width + Self.pageGap
        pager.pin
            .top()
            .bottom()
            .start()
            .width(stride)
        let pageSize = bounds.size
        pager.layoutRow(
            slots,
            spacing: Self.pageGap,
            insets: NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: Self.pageGap),
        ) { _ in pageSize }
        for pageView in pageViews {
            pageView.pin
                .all()
        }
        if pageWidth != stride {
            pageWidth = stride
            pager.contentOffset.x = stride * CGFloat(currentPage)
        }
        pageControl.pin
            .bottom(4)
            .horizontally()
            .sizeToFit(.width)
        loadPages()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: preferredHeight)
    }

    override func accessibilityIncrement() {
        show(page: currentPage + 1, animated: false)
    }

    override func accessibilityDecrement() {
        show(page: currentPage - 1, animated: false)
    }

    override func accessibilityActivate() -> Bool {
        guard !pages.isEmpty, let onOpen else {
            return false
        }
        onOpen(currentPage)
        return true
    }

    // MARK: Functions

    func show(_ spot: SpotIndex, photos: [SpotPhoto], scale: CGFloat) {
        let tint = spot.kind.tint.resolvedColor(with: traitCollection)
        fallback.colors = [tint.cgColor, tint.withBrightness(0.72).cgColor]
        let pages = GalleryPhoto.pages(of: spot, photos: photos)
        glyphView.image = pages.isEmpty ? UIImage(systemName: spot.kind.symbolName) : nil
        fallback.isHidden = !pages.isEmpty
        self.scale = scale
        if spot.id != spotID {
            spotID = spot.id
            currentPage = 0
            pager.contentOffset.x = 0
        }
        if pages != self.pages {
            showPages(pages)
        }
        accessibilityLabel = pages.isEmpty ? spot.kind.title : SpotDetailKitStrings.Spot.Cover.A11y.label(spot.title)
        accessibilityTraits = pages.count > 1 ? [.image, .adjustable] : .image
        updateAccessibilityValue()
        setNeedsLayout()
    }

    func pageView(at page: Int) -> UIImageView? {
        pageViews.indices.contains(page) ? pageViews[page] : nil
    }

    func show(page: Int, animated: Bool) {
        guard pages.indices.contains(page) else {
            return
        }
        currentPage = page
        pager.setContentOffset(CGPoint(x: (bounds.width + Self.pageGap) * CGFloat(page), y: 0), animated: animated)
        loadPages()
    }

    private func showPages(_ pages: [GalleryPhoto]) {
        self.pages = pages
        while pageViews.count < pages.count {
            let slot = UIView()
            slot.backgroundColor = .sheetSecondaryFill
            slot.clipsToBounds = true
            slot.layer.cornerRadius = SpotPageView.cardCornerRadius
            slot.layer.cornerCurve = .continuous
            let view = UIImageView()
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            view.layer.cornerRadius = SpotPageView.cardCornerRadius
            view.layer.cornerCurve = .continuous
            slot.addSubview(view)
            pager.addSubview(slot)
            slots.append(slot)
            pageViews.append(view)
            loaders.append(PhotoLoader())
        }
        while pageViews.count > pages.count {
            slots.removeLast().removeFromSuperview()
            pageViews.removeLast()
            loaders.removeLast()
        }
        pageControl.numberOfPages = pages.count
        currentPage = min(currentPage, max(pages.count - 1, 0))
        pageWidth = 0
    }

    private func updateAccessibilityValue() {
        guard pages.indices.contains(currentPage) else {
            accessibilityValue = nil
            return
        }
        let position = currentPage + 1
        accessibilityValue =
            switch (pages.count > 1, pages[currentPage].credit) {
            case (true, let credit?): SpotDetailKitStrings.Spot.Cover.A11y.positionAndCredit(position, pages.count, credit)
            case (true, nil): SpotDetailKitStrings.Spot.Cover.A11y.position(position, pages.count)
            case (false, let credit?): SpotDetailKitStrings.Spot.Cover.A11y.credit(credit)
            case (false, nil): ""
            }
    }

    private func loadPages() {
        guard !pages.isEmpty else {
            return
        }
        for index in max(currentPage - 1, 0)...min(currentPage + 1, pages.count - 1) {
            let page = pages[index]
            loaders[index].show(key: page.key, thumbhash: page.thumbhash, size: .card, scale: scale, in: pageViews[index])
        }
    }

}

// MARK: Actions

extension CoverCardView {
    @objc
    private func tapped() {
        guard !pages.isEmpty else {
            return
        }
        onOpen?(currentPage)
    }
}

// MARK: UIScrollViewDelegate

extension CoverCardView: UIScrollViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView.isTracking || scrollView.isDecelerating, bounds.width > 0 else {
            return
        }
        let page = Int((scrollView.contentOffset.x / (bounds.width + Self.pageGap)).rounded())
        guard pages.indices.contains(page), page != currentPage else {
            return
        }
        currentPage = page
        loadPages()
    }
}

extension UIColor {
    fileprivate func withBrightness(_ factor: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        return UIColor(hue: hue, saturation: saturation, brightness: brightness * factor, alpha: alpha)
    }
}
