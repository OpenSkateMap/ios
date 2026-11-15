import ComponentKit
import ImageKit
import MapKit
import PinLayout
import ReviewKit
import SpotModelKit
import UIKit

// MARK: - ReviewCardView

final class ReviewCardView: UIView {

    // MARK: Static Properties

    private static let photoHeight: CGFloat = 300
    private static let mapHeight: CGFloat = 150
    private static let inset: CGFloat = 16

    // MARK: Properties

    private(set) var card: ReviewCard
    let scrollView = UIScrollView().softEdges()

    private let photoPager = UIScrollView().softEdges()
    private var photoViews = [UIImageView]()
    private var photoLoaders = [PhotoLoader]()
    private let creditLabel = InsetLabel()
    private let pageLabel = InsetLabel()
    private let titleLabel = Label()
    private let detailLabel = Label()
    private let obstaclesLabel = Label()
    private let changesLabel = Label()
    private let submitterLabel = Label()
    private let noteLabel = Label()
    private let nearbyLabel = Label()
    private let mapView = UIImageView()
    private let approveStamp = InsetLabel()
    private let rejectStamp = InsetLabel()
    private var snapshotSize = CGSize.zero
    private var requestedSnapshotSize = CGSize.zero
    private var snapshotter: MKMapSnapshotter?
    private var snapshotting: Task<Void, Never>?

    // MARK: Lifecycle

    init(card: ReviewCard, cityName: String?) {
        self.card = card
        super.init(frame: .zero)
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 28
        layer.cornerCurve = .continuous
        clipsToBounds = true

        photoPager.isPagingEnabled = true
        photoPager.showsHorizontalScrollIndicator = false
        photoPager.delegate = self
        creditLabel.linesAtAccessibilitySizes = 0
        for label in [creditLabel, pageLabel] {
            label.font = .preferredFont(forTextStyle: .caption1, weight: .semibold)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .white
            label.backgroundColor = UIColor.black.withAlphaComponent(0.45)
            label.layer.cornerRadius = 10
            label.clipsToBounds = true
        }
        titleLabel.font = .preferredFont(forTextStyle: .title2, weight: .bold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2
        for label in [detailLabel, obstaclesLabel, submitterLabel] {
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            label.numberOfLines = 0
        }
        noteLabel.font = .preferredFont(forTextStyle: .body)
        noteLabel.adjustsFontForContentSizeCategory = true
        noteLabel.numberOfLines = 0
        changesLabel.numberOfLines = 0
        nearbyLabel.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        nearbyLabel.adjustsFontForContentSizeCategory = true
        nearbyLabel.textColor = .systemOrange
        nearbyLabel.numberOfLines = 0
        mapView.contentMode = .scaleAspectFill
        mapView.clipsToBounds = true
        mapView.layer.cornerRadius = 16
        mapView.layer.cornerCurve = .continuous
        mapView.backgroundColor = .tertiarySystemFill
        for (stamp, text, color) in [
            (approveStamp, ContributeKitStrings.ReviewCard.Stamp.approve, UIColor.systemGreen),
            (rejectStamp, ContributeKitStrings.ReviewCard.Stamp.reject, UIColor.systemRed),
        ] {
            stamp.text = text
            stamp.font = .systemFont(ofSize: 22, weight: .heavy)
            stamp.textColor = color
            stamp.layer.borderColor = color.cgColor
            stamp.layer.borderWidth = 3
            stamp.layer.cornerRadius = 8
            stamp.alpha = 0
            stamp.accessibilityElementsHidden = true
        }

        addSubview(scrollView)
        scrollView.addSubview(photoPager)
        for view in [
            creditLabel,
            pageLabel,
            titleLabel,
            detailLabel,
            obstaclesLabel,
            changesLabel,
            submitterLabel,
            noteLabel,
            nearbyLabel,
            mapView,
        ] {
            scrollView.addSubview(view)
        }
        addSubview(approveStamp)
        addSubview(rejectStamp)
        configure(card, cityName: cityName)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        snapshotting?.cancel()
        snapshotter?.cancel()
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.pin
            .all()
        let width = bounds.width
        let contentWidth = width - Self.inset * 2
        let photoHeight = photoViews.isEmpty ? 0 : Self.photoHeight
        photoPager.pin
            .top()
            .start()
            .width(width)
            .height(photoHeight)
        photoPager.layoutRow(photoViews, spacing: 0) { _ in CGSize(width: width, height: photoHeight) }
        pageLabel.pin
            .bottomEnd(to: photoPager.anchor.bottomEnd)
            .margin(12)
            .sizeToFit()
        let creditWidth = max(width - pageLabel.frame.width - 12 * 2 - 8, 0)
        let credit = creditLabel.sizeThatFits(CGSize(width: creditWidth, height: .greatestFiniteMagnitude))
        creditLabel.pin
            .bottomStart(to: photoPager.anchor.bottomStart)
            .width(min(credit.width, creditWidth))
            .height(credit.height)
            .margin(12)
        titleLabel.pin
            .below(of: photoPager)
            .start(Self.inset)
            .width(contentWidth)
            .marginTop(photoViews.isEmpty ? 24 : 16)
            .sizeToFit(.width)
        detailLabel.pin
            .below(of: titleLabel)
            .start(Self.inset)
            .width(contentWidth)
            .marginTop(4)
            .sizeToFit(.width)
        obstaclesLabel.pin
            .below(of: detailLabel)
            .start(Self.inset)
            .width(contentWidth)
            .marginTop(4)
            .sizeToFit(.width)
        changesLabel.pin
            .below(of: obstaclesLabel)
            .start(Self.inset)
            .width(contentWidth)
            .marginTop(changesLabel.attributedText == nil ? 0 : 16)
            .sizeToFit(.width)
        nearbyLabel.pin
            .below(of: changesLabel)
            .start(Self.inset)
            .width(contentWidth)
            .marginTop(nearbyLabel.text == nil ? 0 : 12)
            .sizeToFit(.width)
        mapView.pin
            .below(of: nearbyLabel)
            .start(Self.inset)
            .width(contentWidth)
            .height(Self.mapHeight)
            .marginTop(16)
        submitterLabel.pin
            .below(of: mapView)
            .start(Self.inset)
            .width(contentWidth)
            .marginTop(16)
            .sizeToFit(.width)
        noteLabel.pin
            .below(of: submitterLabel)
            .start(Self.inset)
            .width(contentWidth)
            .marginTop(4)
            .sizeToFit(.width)
        scrollView.contentSize = CGSize(width: width, height: noteLabel.frame.maxY + 24)
        // swiftlint:disable pinlayout_left_right - each stamp shows on the side its swipe leaves from
        approveStamp.pin
            .top(24)
            .left(20)
            .sizeToFit()
        rejectStamp.pin
            .top(24)
            .right(20)
            .sizeToFit()
        // swiftlint:enable pinlayout_left_right
        approveStamp.transform = CGAffineTransform(rotationAngle: -0.25)
        rejectStamp.transform = CGAffineTransform(rotationAngle: 0.25)
        snapshotIfNeeded()
    }

    // MARK: Static Functions

    static func changes(_ card: ReviewCard) -> NSAttributedString {
        let text = NSMutableAttributedString(
            string: ContributeKitStrings.ReviewCard.Changes.header,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .headline), .foregroundColor: UIColor.tintColor],
        )
        let lines: [String] =
            if let current = card.current {
                card.changedFields.map { change(of: $0, from: current, to: card) }
            } else {
                [ContributeKitStrings.ReviewCard.Changes.spotGone]
            }
        let body: [NSAttributedString.Key: Any] = [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label,
        ]
        for line in lines {
            text.append(NSAttributedString(string: "\n\(line)", attributes: body))
        }
        return text
    }

    private static func change(of field: SpotEditField, from current: ReviewCard.Snapshot, to card: ReviewCard) -> String {
        let none = ContributeKitStrings.ReviewCard.Changes.empty
        switch field {
        case .title:
            return ContributeKitStrings.ReviewCard.Changes.name(current.title, card.title)

        case .description:
            return ContributeKitStrings.ReviewCard.Changes.about(
                current.about.isEmpty ? none : current.about,
                card.about.isEmpty ? none : card.about,
            )

        case .spotKind:
            return ContributeKitStrings.ReviewCard.Changes.kind(current.kind.title, card.kind.title)

        case .obstacles:
            let list = { (obstacles: [String]) in obstacles.isEmpty ? none : Self.obstacleList(obstacles) }
            return ContributeKitStrings.ReviewCard.Changes.obstacles(list(current.obstacles), list(card.obstacles))

        case .condition:
            return ContributeKitStrings.ReviewCard.Changes.condition(current.condition.title, card.condition.title)

        case .location:
            let from = CLLocation(latitude: current.latitude, longitude: current.longitude)
            let meters = Int(from.distance(from: CLLocation(latitude: card.latitude, longitude: card.longitude)).rounded())
            return ContributeKitStrings.ReviewCard.Changes.pinMoved(meters)

        case .photos:
            let added = card.photos.count { !$0.isExisting }
            let removed = current.removedPhotoCount
            let lines = [
                added > 0 ? ContributeKitStrings.ReviewCard.Changes.photos(added) : nil,
                removed > 0 ? ContributeKitStrings.ReviewCard.Changes.photosRemoved(removed) : nil,
            ].compactMap(\.self)
            return lines.isEmpty ? ContributeKitStrings.ReviewCard.Changes.photosReordered : lines.joined(separator: "\n")
        }
    }

    private static func obstacleList(_ obstacles: [String]) -> String {
        obstacles.map(SpotObstacle.name(of:)).formatted(.list(type: .and, width: .narrow))
    }

    // MARK: Functions

    func setVerdictHint(_ value: CGFloat) {
        approveStamp.alpha = max(0, min(1, value))
        rejectStamp.alpha = max(0, min(1, -value))
    }

    func configure(_ card: ReviewCard, cityName: String?) {
        self.card = card
        titleLabel.text = card.title
        detailLabel.text = [card.kind.title, cityName ?? ContributeKitStrings.ReviewCard.outsideCities, card.condition.title]
            .joined(separator: " · ")
        obstaclesLabel.text = card.obstacles.isEmpty
            ? ContributeKitStrings.ReviewCard.noObstacles
            : Self.obstacleList(card.obstacles)
        changesLabel.attributedText = card.isEdit ? Self.changes(card) : nil
        let nearby = card.nearby.map { ContributeKitStrings.ReviewCard.Nearby.spot($0.title, $0.distanceText) }
        nearbyLabel.text = nearby.isEmpty ? nil : ContributeKitStrings.ReviewCard.Nearby.list(nearby.joined(separator: ", "))
        submitterLabel.text = card.submitterName.map { ContributeKitStrings.ReviewCard.sentBy($0) }
            ?? ContributeKitStrings.ReviewCard.sentByDeletedAccount
        noteLabel.text = card.note.isEmpty
            ? ContributeKitStrings.ReviewCard.noNote
            : ContributeKitStrings.ReviewCard.note(card.note)
        noteLabel.textColor = card.note.isEmpty ? .tertiaryLabel : .label
        showPhotos(card.photos)
        snapshotSize = .zero
        requestedSnapshotSize = .zero
        let summary = card.isEdit ? changesLabel.attributedText?.string ?? "" : nearbyLabel.text ?? ""
        accessibilityLabel = ContributeKitStrings.ReviewCard.A11y.label(card.title, detailLabel.text ?? "", summary)
        accessibilityContainerType = .semanticGroup
        setNeedsLayout()
    }

    private func showPhotos(_ photos: [ReviewCard.Photo]) {
        for view in photoViews {
            view.removeFromSuperview()
        }
        photoLoaders = photos.map { _ in PhotoLoader() }
        photoViews = photos.map { _ in
            let view = UIImageView()
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            view.backgroundColor = .tertiarySystemFill
            photoPager.addSubview(view)
            return view
        }
        photoPager.contentOffset = .zero
        showPage(0)
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 3
        for (index, photo) in photos.enumerated() {
            photoLoaders[index].show(key: photo.key, thumbhash: photo.thumbhash, size: .card, scale: scale, in: photoViews[index])
        }
    }

    private func showPage(_ page: Int) {
        guard card.photos.indices.contains(page) else {
            creditLabel.text = nil
            pageLabel.text = nil
            return
        }
        let photo = card.photos[page]
        creditLabel.text = photo.creditText
        pageLabel.text = ContributeKitStrings.ReviewCard.page(page + 1, card.photos.count)
        setNeedsLayout()
    }

    private func snapshotIfNeeded() {
        let size = mapView.bounds.size
        guard size.width > 0, size != snapshotSize, size != requestedSnapshotSize else {
            return
        }
        requestedSnapshotSize = size
        let options = MKMapSnapshotter.Options()
        let center = CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude)
        options.region = MKCoordinateRegion(center: center, latitudinalMeters: 500, longitudinalMeters: 500)
        options.size = size
        options.traitCollection = traitCollection
        let snapshotter = MKMapSnapshotter(options: options)
        let traits = traitCollection
        self.snapshotter?.cancel()
        self.snapshotter = snapshotter
        snapshotting?.cancel()
        snapshotting = Task { [weak self, mapView] in
            let snapshot = try? await snapshotter.start()
            guard let self, !Task.isCancelled else {
                return
            }
            // A failed one (offline, throttled) is asked for again at the next layout.
            requestedSnapshotSize = .zero
            guard let snapshot else {
                return
            }
            snapshotSize = size
            let point = snapshot.point(for: center)
            let renderer = UIGraphicsImageRenderer(size: size)
            mapView.image = renderer.image { _ in
                snapshot.image.resolved(with: traits).draw(at: .zero)
                LocationPin.image.draw(at: CGPoint(x: point.x - LocationPin.tip.x, y: point.y - LocationPin.tip.y))
            }
        }
    }
}

// MARK: UIScrollViewDelegate

extension ReviewCardView: UIScrollViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView === photoPager, scrollView.bounds.width > 0 else {
            return
        }
        showPage(Int((scrollView.contentOffset.x / scrollView.bounds.width).rounded()))
    }
}
