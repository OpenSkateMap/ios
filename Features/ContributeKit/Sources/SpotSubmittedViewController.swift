import AppLinkKit
import ComponentKit
import FactoryKit
import PinLayout
import UIKit

final class SpotSubmittedViewController: UIViewController {

    // MARK: Types

    /// The check draws itself in once, as the page lands; with Reduce Motion it's simply there.
    private enum Success {
        case notShown
        case drawnOff
        case shown
    }

    // MARK: Computed Properties

    private var isSent: Bool {
        switch model.status {
        case .sending, .sent: true
        case .waitingForNetwork, .failed: false
        }
    }

    // MARK: Properties

    private let model: SpotSubmittedModel
    private let onViewInContribute: () -> Void
    private let onAddAnother: (() -> Void)?
    private let background = TintedBackgroundView()
    private let scrollView = UIScrollView().softEdges()
    private let iconView = UIImageView()
    private let headlineLabel = Label()
    private let nameLabel = Label()
    private let separator = UIView()
    private let placeLabel = Label()
    private let mapView = SpotLocationMapView()
    private let messageLabel = Label()
    private let nextSpotsView = NextSpotsView()
    private let viewButton = UIButton(configuration: .primaryCapsule(title: ContributeKitStrings.SpotSubmitted.viewInContribute))
    private let anotherButton = UIButton(configuration: .secondaryCapsule(title: ContributeKitStrings.SpotSubmitted.addAnother))
    @Injected(\.appLinkOpener) private var links
    private var success = Success.notShown

    // MARK: Lifecycle

    init(model: SpotSubmittedModel,
         tint: UIColor?,
         onViewInContribute: @escaping () -> Void,
         onAddAnother: (() -> Void)?) {
        self.model = model
        self.onViewInContribute = onViewInContribute
        self.onAddAnother = onAddAnother
        super.init(nibName: nil, bundle: nil)
        background.tint = tint
        navigationItem.hidesBackButton = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupActions()
        Task { [model] in await model.loadNextSpots() }
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        guard success == .notShown, isSent, !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        iconView.addSymbolEffect(.drawOff, animated: false)
        success = .drawnOff
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if success == .drawnOff {
            iconView.addSymbolEffect(.drawOn)
        }
        success = .shown
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        background.pin
            .all()
        let sides = UIEdgeInsets(top: 0, left: view.safeAreaInsets.left + 20, bottom: 0, right: view.safeAreaInsets.right + 20)
        let width = view.bounds.width - sides.left - sides.right
        if anotherButton.isHidden {
            viewButton.pin
                .bottom(view.pin.safeArea.bottom + 12)
                .start(sides)
                .width(width)
                .height(viewButton.capsuleHeight(fitting: width))
        } else {
            anotherButton.pin
                .bottom(view.pin.safeArea.bottom + 12)
                .start(sides)
                .width(width)
                .height(anotherButton.capsuleHeight(fitting: width))
            viewButton.pin
                .above(of: anotherButton)
                .start(sides)
                .width(width)
                .height(viewButton.capsuleHeight(fitting: width))
                .marginBottom(10)
        }
        scrollView.pin
            .top()
            .bottom(to: viewButton.edge.top)
            .horizontally()
            .marginBottom(12)
        iconView.pin
            .top(view.safeAreaInsets.top + 24)
            .hCenter()
            .size(96)
        headlineLabel.pin
            .below(of: iconView)
            .start(sides)
            .width(width)
            .marginTop(16)
            .sizeToFit(.width)
        nameLabel.pin
            .below(of: headlineLabel)
            .start(sides)
            .width(width)
            .marginTop(6)
            .sizeToFit(.width)
        separator.pin
            .below(of: nameLabel)
            .start(sides)
            .width(width)
            .height(1 / max(traitCollection.displayScale, 1))
            .marginTop(20)
        placeLabel.pin
            .below(of: separator)
            .start(sides)
            .width(width)
            .marginTop(16)
            .sizeToFit(.width)
        mapView.pin
            .below(of: placeLabel)
            .start(sides)
            .width(width)
            .height(150)
            .marginTop(12)
        messageLabel.pin
            .below(of: mapView)
            .start(sides)
            .width(width)
            .marginTop(16)
            .sizeToFit(.width)
        nextSpotsView.pin
            .below(of: messageLabel)
            .start(sides)
            .width(width)
            .height(nextSpotsView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
            .marginTop(28)
        let contentBottom = nextSpotsView.isHidden ? messageLabel.frame.maxY : nextSpotsView.frame.maxY
        scrollView.contentSize = CGSize(width: view.bounds.width, height: contentBottom + 16)
    }

    override func updateProperties() {
        super.updateProperties()

        let symbol: String
        let color: UIColor
        switch model.status {
        case .sending, .sent:
            symbol = "checkmark.circle.fill"
            color = .systemGreen
            if let collection = model.collection {
                headlineLabel.text = ContributeKitStrings.SpotSubmitted.Collection.title
                messageLabel.text = ContributeKitStrings.SpotSubmitted.Collection.message(collection)
            } else {
                switch (model.isEdit, model.isReviewed) {
                case (false, true):
                    headlineLabel.text = ContributeKitStrings.SpotSubmitted.title
                    messageLabel.text = ContributeKitStrings.SpotSubmitted.message

                case (false, false):
                    headlineLabel.text = ContributeKitStrings.SpotSubmitted.DirectSpot.title
                    messageLabel.text = ContributeKitStrings.SpotSubmitted.DirectSpot.message

                case (true, true):
                    headlineLabel.text = ContributeKitStrings.SpotSubmitted.Edit.title
                    messageLabel.text = ContributeKitStrings.SpotSubmitted.Edit.message

                case (true, false):
                    headlineLabel.text = ContributeKitStrings.SpotSubmitted.DirectEdit.title
                    messageLabel.text = ContributeKitStrings.SpotSubmitted.DirectEdit.message
                }
            }

        case .waitingForNetwork:
            symbol = "clock.fill"
            color = .secondaryLabel
            headlineLabel.text = ContributeKitStrings.SpotSubmitted.Waiting.title
            messageLabel.text = ContributeKitStrings.SpotSubmitted.Waiting.message

        case .failed(let reason):
            symbol = "exclamationmark.circle.fill"
            color = .systemRed
            headlineLabel.text = ContributeKitStrings.SpotSubmitted.Failed.title
            messageLabel.text = ContributeKitStrings.SpotSubmitted.Failed.message(reason)
        }
        iconView.image = UIImage(systemName: symbol)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 72, weight: .regular))
            .withTintColor(color, renderingMode: .alwaysOriginal)
        if !isSent {
            iconView.removeAllSymbolEffects()
        }
        showNextSpots(model.nextSpots)
        view.setNeedsLayout()
    }

    // MARK: Static Functions

    private static func place(_ location: NewSpotForm.Location) -> NSAttributedString {
        let text = NSMutableAttributedString()
        if let pin = UIImage(systemName: "mappin.and.ellipse")?.withTintColor(.secondaryLabel, renderingMode: .alwaysOriginal) {
            text.append(NSAttributedString(attachment: NSTextAttachment(image: pin)))
            text.append(NSAttributedString(string: "  "))
        }
        text.append(NSAttributedString(
            string: location.name,
            attributes: [.font: UIFont.preferredFont(forTextStyle: .body), .foregroundColor: UIColor.label],
        ))
        if let subtitle = location.subtitle {
            text.append(NSAttributedString(
                string: "\n\(subtitle)",
                attributes: [.font: UIFont.preferredFont(forTextStyle: .subheadline), .foregroundColor: UIColor.secondaryLabel],
            ))
        }
        return text
    }

    // MARK: Functions

    private func setupViews() {
        view.backgroundColor = .systemBackground
        iconView.contentMode = .center
        headlineLabel.font = .preferredFont(forTextStyle: .title3, weight: .semibold)
        headlineLabel.adjustsFontForContentSizeCategory = true
        headlineLabel.textAlignment = .center
        headlineLabel.numberOfLines = 0
        headlineLabel.accessibilityTraits = .header
        nameLabel.font = .preferredFont(forTextStyle: .title1, weight: .bold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 0
        nameLabel.text = model.title
        separator.backgroundColor = .separator
        placeLabel.numberOfLines = 0
        placeLabel.attributedText = Self.place(model.location)
        placeLabel.accessibilityLabel = [model.location.name, model.location.subtitle].compactMap(\.self).joined(separator: ", ")
        mapView.show(model.location.coordinate)
        mapView.layer.cornerRadius = 20
        mapView.layer.cornerCurve = .continuous
        mapView.clipsToBounds = true
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.textColor = .secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        anotherButton.isHidden = onAddAnother == nil
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = false
        nextSpotsView.isHidden = true
        for subview in [iconView, headlineLabel, nameLabel, separator, placeLabel, mapView, messageLabel, nextSpotsView] {
            scrollView.addSubview(subview)
        }
        for subview in [background, scrollView, viewButton, anotherButton] {
            view.addSubview(subview)
        }
    }

    private func setupActions() {
        viewButton.addAction(UIAction { [weak self] _ in self?.onViewInContribute() }, for: .primaryActionTriggered)
        anotherButton.addAction(UIAction { [weak self] _ in self?.onAddAnother?() }, for: .primaryActionTriggered)
        nextSpotsView.onOpen = { [weak self] id in self?.links.open(.spot(id: id)) }
        nextSpotsView.onAddPhotos = { id in Container.shared.spotEditOpener()?(id) }
    }

    /// Spots that arrive once the page is up fade in rather than pop; none hides the section.
    private func showNextSpots(_ spots: [NearYou.Spot]) {
        nextSpotsView.show(spots)
        let wasHidden = nextSpotsView.isHidden
        nextSpotsView.isHidden = spots.isEmpty
        guard wasHidden, !spots.isEmpty, success == .shown else {
            return
        }
        nextSpotsView.alpha = 0
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            self.nextSpotsView.alpha = 1
        }
    }

}
