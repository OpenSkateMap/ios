import ComponentKit
import CoreLocation
import FactoryKit
import ImageKit
import PinLayout
import SpotModelKit
import SpotsKit
import UIKit

// MARK: - SpotPageView

final class SpotPageView: UIView {

    // MARK: Static Properties

    static let margin: CGFloat = 20
    static let cardCornerRadius: CGFloat = 20

    private static let titleSpacing: CGFloat = 14
    private static let metaSpacing: CGFloat = 4
    private static let tilesSpacing: CGFloat = 16
    private static let summaryBottom: CGFloat = 18

    private static let topInset: CGFloat = 20
    private static let bottomInset: CGFloat = 32
    private static let minimumCoverHeight: CGFloat = 150

    // MARK: Computed Properties

    var coverImage: UIImage? {
        cover.image
    }

    /// Where the title ends, in the page's coordinates.
    var titleBottom: CGFloat {
        titleLabel.convert(titleLabel.bounds, to: self).maxY
    }

    private var pageRows: [(view: UIView, spacingBefore: CGFloat)] {
        [
            (cover, 0),
            (titleLabel, Self.titleSpacing),
            (metaLabel, Self.metaSpacing),
            (tiles, Self.tilesSpacing),
            (location, 28),
            (obstacles, 28),
            (about, 28),
            (addedByButton, 24),
            (rating, 28),
            (videos, 28),
            (detailsStatusButton, 28),
        ]
    }

    private var displayScale: CGFloat {
        traitCollection.displayScale > 0 ? traitCollection.displayScale : 3
    }

    // MARK: Properties

    /// While the sheet's title bar names the spot, the page's title under it steps aside.
    var isTitleHidden = false {
        didSet {
            titleLabel.alpha = isTitleHidden ? 0 : 1
            titleLabel.accessibilityElementsHidden = isTitleHidden
        }
    }

    var summaryHeight: CGFloat = 420 {
        didSet {
            setNeedsLayout()
        }
    }

    let cover = CoverCardView()
    let starButton = UIButton(configuration: .glassIcon("star", textStyle: .body))

    /// `nil` hides the star.
    var isStarred: Bool? {
        didSet {
            starButton.isHidden = isStarred == nil
            let color: UIColor = isStarred == true ? .systemYellow : .label
            starButton.configuration?.image = UIImage(systemName: isStarred == true ? "star.fill" : "star")
            // Glass draws its own foreground; the image keeps the star's colour.
            starButton.configuration?.imageColorTransformer = UIConfigurationColorTransformer { _ in color }
            starButton.accessibilityLabel = isStarred == true
                ? SpotDetailKitStrings.Spot.Star.remove
                : SpotDetailKitStrings.Spot.Star.add
        }
    }

    let tiles = ActionTilesView()
    let addedByButton = UIButton(configuration: .plain())
    let mapCard = SpotMapCardView()
    let videosSection = SpotVideosSectionView(loader: Container.shared.imageLoader())
    let addVideoButton = UIButton(configuration: .plain())
    let ratingView = SpotRatingView()
    let detailsStatusButton = UIButton(configuration: .plain())
    var detailsLoad = DetailsLoad.idle {
        didSet {
            updateDetailsStatus()
        }
    }

    let addressLabel = Label()

    private let stack = FormStackView()
    private let titleLabel = Label()
    private let metaLabel = Label()
    private let chipsView = ChipsView()
    private let aboutLabel = Label()
    private var hasDetails = false
    private lazy var location = SpotPageSectionView(
        title: SpotDetailKitStrings.Spot.Section.location,
        rows: [(addressLabel, nil), (mapCard, 160)],
    )
    private lazy var obstacles = SpotPageSectionView(title: SpotDetailKitStrings.Spot.Section.obstacles, rows: [(chipsView, nil)])
    private lazy var about = SpotPageSectionView(title: SpotDetailKitStrings.Spot.Section.about, rows: [(aboutLabel, nil)])
    private lazy var rating = SpotPageSectionView(
        title: SpotDetailKitStrings.Spot.Section.rating,
        rows: [(ratingView, nil)],
    )
    private lazy var videos = SpotPageSectionView(
        title: SpotDetailKitStrings.Spot.Section.videos,
        accessory: addVideoButton,
        rows: [(videosSection, nil)],
    )

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = .preferredFont(forTextStyle: .title2, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2
        titleLabel.accessibilityTraits = .header
        metaLabel.numberOfLines = 2
        metaLabel.font = .preferredFont(forTextStyle: .subheadline)
        metaLabel.adjustsFontForContentSizeCategory = true
        metaLabel.textColor = .sheetSecondaryLabel

        for label in [addressLabel, aboutLabel] {
            label.font = .preferredFont(forTextStyle: .body)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
        }
        detailsStatusButton.configuration?.contentInsets = .zero
        detailsStatusButton.configuration?.imagePadding = 8
        detailsStatusButton.contentHorizontalAlignment = .leading
        updateDetailsStatus()

        var addedBy = UIButton.Configuration.plain()
        addedBy.contentInsets = .zero
        addedBy.baseForegroundColor = .sheetSecondaryLabel
        addedByButton.configuration = addedBy
        addedByButton.contentHorizontalAlignment = .leading
        addedByButton.accessibilityHint = SpotDetailKitStrings.Spot.A11y.addedByHint

        var addVideo = UIButton.Configuration.plain()
        addVideo.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
        addVideo.image = UIImage(systemName: "plus")
        addVideo.imagePadding = 4
        addVideo.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .small)
        addVideo.title = SpotDetailKitStrings.Spot.Videos.add
        addVideo.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
            return attributes
        }
        addVideoButton.configuration = addVideo

        for row in pageRows {
            stack.add(row.view, spacingBefore: row.spacingBefore)
        }
        addSubview(stack)
        addSubview(starButton)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layoutPage(width: bounds.width)
        starButton.pin
            .bottomEnd(to: cover.anchor.bottomEnd)
            .size(44)
            .marginBottom(10)
            .marginEnd(10)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layoutPage(width: size.width))
    }

    // MARK: Functions

    func show(_ page: SpotPage, address: String?) {
        guard let spot = page.spot else {
            return
        }
        let detail = page.detail
        titleLabel.text = spot.title
        ratingView.show(
            up: detail?.upvotes ?? 0,
            down: detail?.downvotes ?? 0,
            mine: detail?.myVote ?? .none,
            isEnabled: detail != nil,
        )
        ratingView.isHidden = spot.isPrivate
        let condition = spot.condition == .skateable ? nil : spot.condition.title
        metaLabel.text = [spot.kind.title, page.city?.localizedName, condition].compactMap(\.self).joined(separator: " · ")
        cover.show(spot, photos: page.photos, scale: displayScale)

        mapCard.show(CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude))
        addressLabel.text = address ?? page.city?.localizedName ?? SpotDetailKitStrings.Spot.findingAddress

        chipsView.show(detail?.obstacles ?? [])
        chipsView.isHidden = detail?.obstacles.isEmpty ?? true
        aboutLabel.text = detail?.about
        aboutLabel.isHidden = detail?.about.isEmpty ?? true
        if let name = detail?.addedByName {
            var title = AttributedString(SpotDetailKitStrings.Spot.addedBy(name))
            // Searched from the end, where English puts the name, in case the sentence's own words contain it.
            if let person = title.range(of: name, options: .backwards) {
                title[person].foregroundColor = detail?.addedByID == nil ? .sheetSecondaryLabel : .tintColor
            }
            title.font = .preferredFont(forTextStyle: .body)
            addedByButton.configuration?.attributedTitle = title
        }
        addedByButton.isHidden = detail?.addedByName == nil
        addedByButton.isEnabled = detail?.addedByID != nil
        videosSection.show(page.videos, draft: page.videoDraft)
        videosSection.isHidden = detail == nil || spot.isPrivate
        hasDetails = detail != nil
        updateDetailsStatus()
        for section in [location, obstacles, about, rating, videos] {
            section.updateVisibility()
        }
        setNeedsLayout()
    }

    private func updateDetailsStatus() {
        detailsStatusButton.isHidden = hasDetails
        let failed = detailsLoad == .failed
        var title = AttributedString(failed
            ? SpotDetailKitStrings.Spot.Details.failedInline + " "
            : SpotDetailKitStrings.Spot.loading)
        title.foregroundColor = .sheetSecondaryLabel
        if failed {
            var retry = AttributedString(SpotDetailKitStrings.Spot.Details.retry)
            retry.foregroundColor = .tintColor
            title += retry
        }
        title.font = .preferredFont(forTextStyle: .body)
        detailsStatusButton.configuration?.attributedTitle = title
        detailsStatusButton.configuration?.showsActivityIndicator = detailsLoad == .loading
        detailsStatusButton.isUserInteractionEnabled = failed
        detailsStatusButton.accessibilityTraits = failed ? .button : .staticText
        setNeedsLayout()
    }

    @discardableResult
    private func layoutPage(width: CGFloat) -> CGFloat {
        let content = width - Self.margin * 2
        cover.preferredHeight = coverHeight(contentWidth: content)
        let height = stack.sizeThatFits(CGSize(width: content, height: .greatestFiniteMagnitude)).height
        stack.pin
            .top(Self.topInset)
            .start(Self.margin)
            .width(content)
            .height(height)
        return Self.topInset + height + Self.bottomInset
    }

    private func coverHeight(contentWidth: CGFloat) -> CGFloat {
        let fitting = CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
        let text = titleLabel.sizeThatFits(fitting).height + Self.metaSpacing + metaLabel.sizeThatFits(fitting).height
        let below = Self.titleSpacing + text + Self.tilesSpacing + tiles.sizeThatFits(fitting).height + Self.summaryBottom
        return min(max(summaryHeight - Self.topInset - below, Self.minimumCoverHeight), contentWidth).rounded()
    }
}
