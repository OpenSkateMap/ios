import ComponentKit
import FactoryKit
import LibraryMatchKit
import PinLayout
import SpotModelKit
import UIKit

/// A photo from the person's library taken at a spot: the photo, "Shot this at <spot> in <year>?", Add to Spot and
/// Not This One.
final class LibraryMatchCell: UICollectionViewCell {

    // MARK: Static Properties

    static let width: CGFloat = 200

    private static let photoAspect: CGFloat = 3 / 4
    private static let inset: CGFloat = 12

    // MARK: Properties

    var onAdd: (() -> Void)?
    var onSkip: (() -> Void)?

    @Injected(\.photoLibrary) private var library

    private let photoView = UIImageView()
    private let questionLabel = Label()
    private let addButton =
        UIButton(configuration: .primaryCapsule(title: ContributeKitStrings.Contribute.FromYourPhotos.addToSpot))
    private let skipButton = UIButton(configuration: .primaryCapsule(title: ContributeKitStrings.Contribute.FromYourPhotos.skip))
    private var loading: Task<Void, Never>?

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 20
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true
        photoView.clipsToBounds = true
        photoView.contentMode = .scaleAspectFill
        photoView.backgroundColor = .tertiarySystemFill
        questionLabel.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        questionLabel.adjustsFontForContentSizeCategory = true
        questionLabel.numberOfLines = 3
        questionLabel.linesAtAccessibilitySizes = 0
        skipButton.configuration?.baseBackgroundColor = .tertiarySystemFill
        skipButton.configuration?.baseForegroundColor = .label
        for button in [addButton, skipButton] {
            button.configuration?.buttonSize = .small
            button.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)
            button.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.preferredFont(forTextStyle: .subheadline, weight: .semibold)
                return attributes
            }
        }
        addButton.addAction(UIAction { [weak self] _ in self?.onAdd?() }, for: .primaryActionTriggered)
        skipButton.addAction(UIAction { [weak self] _ in self?.onSkip?() }, for: .primaryActionTriggered)
        for view in [photoView, questionLabel, addButton, skipButton] {
            contentView.addSubview(view)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: ContributeKitStrings.Contribute.FromYourPhotos.addToSpot) { [weak self] _ in
                self?.onAdd?()
                return true
            },
            UIAccessibilityCustomAction(name: ContributeKitStrings.Contribute.FromYourPhotos.skip) { [weak self] _ in
                self?.onSkip?()
                return true
            },
        ]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func prepareForReuse() {
        super.prepareForReuse()

        loading?.cancel()
        loading = nil
        photoView.image = nil
        onAdd = nil
        onSkip = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: contentView.bounds.width)
        // Every card in the row is as tall as the tallest: the buttons line up along the bottom.
        skipButton.pin
            .bottom(Self.inset)
            .start(Self.inset)
            .width(skipButton.bounds.width)
            .height(skipButton.bounds.height)
        addButton.pin
            .above(of: skipButton)
            .start(Self.inset)
            .width(addButton.bounds.width)
            .height(addButton.bounds.height)
            .marginBottom(6)
    }

    override func accessibilityActivate() -> Bool {
        onAdd?()
        return true
    }

    // MARK: Static Functions

    /// The year it was taken, or the month when that's this year.
    static func question(for card: LibraryMatchCard, now: Date = .now, calendar: Calendar = .current) -> String {
        let strings = ContributeKitStrings.Contribute.FromYourPhotos.Question.self
        let takenAt = card.match.takenAt
        if calendar.isDate(takenAt, equalTo: now, toGranularity: .year) {
            return strings.month(card.spotTitle, takenAt.formatted(.dateTime.month(.wide)))
        }
        return strings.year(card.spotTitle, takenAt.formatted(.dateTime.year()))
    }

    /// The tallest of these cards at `width`, measured with the text they'd show.
    static func height(fitting cards: [LibraryMatchCard], width: CGFloat, traits: UITraitCollection) -> CGFloat {
        let sizing = LibraryMatchCell()
        sizing.traitOverrides.preferredContentSizeCategory = traits.preferredContentSizeCategory
        return cards.map { card in
            sizing.questionLabel.text = question(for: card)
            return sizing.height(fitting: width)
        }.max() ?? 0
    }

    // MARK: Functions

    func configure(with card: LibraryMatchCard) {
        questionLabel.text = Self.question(for: card)
        accessibilityLabel = questionLabel.text
        accessibilityUserInputLabels = [card.spotTitle]
        loading?.cancel()
        let side = Self.width * traitCollection.displayScale
        let assetID = card.match.assetID
        loading = Task { [library, weak self] in
            let image = await library.image(assetID, side, true)
            guard !Task.isCancelled else {
                return
            }
            self?.photoView.image = image
        }
        setNeedsLayout()
    }

    private func height(fitting width: CGFloat) -> CGFloat {
        layout(width: width)
        return skipButton.frame.maxY + Self.inset
    }

    private func layout(width: CGFloat) {
        let inset = Self.inset
        let inner = width - inset * 2
        photoView.pin
            .top()
            .start()
            .width(width)
            .height((width * Self.photoAspect).rounded())
        questionLabel.pin
            .below(of: photoView)
            .start(inset)
            .width(inner)
            .marginTop(10)
            .sizeToFit(.width)
        addButton.pin
            .below(of: questionLabel)
            .start(inset)
            .width(inner)
            .height(buttonHeight(addButton, width: inner))
            .marginTop(10)
        skipButton.pin
            .below(of: addButton)
            .start(inset)
            .width(inner)
            .height(buttonHeight(skipButton, width: inner))
            .marginTop(6)
    }

    private func buttonHeight(_ button: UIButton, width: CGFloat) -> CGFloat {
        max(36, ceil(button.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
    }
}
