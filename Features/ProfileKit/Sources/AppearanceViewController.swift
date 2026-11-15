import ComponentKit
import os
import PinLayout
import UIKit

// MARK: - AppearanceViewController

final class AppearanceViewController: UIViewController {

    // MARK: Properties

    private let scrollView = UIScrollView().softEdges()
    private let headerLabel = Label()
    private let detailLabel = Label()
    private let tiles = ColorScheme.allCases.map { _ in UIButton(configuration: .plain()) }
    private let feedback = UISelectionFeedbackGenerator()
    private let iconHeaderLabel = Label()
    private lazy var iconRows = UIApplication.shared.supportsAlternateIcons
        ? AppIcon.allCases.map { AppIconRow(icon: $0) }
        : []
    private let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "appearance")
    private var shownIcon = AppIcon.current
    /// Only the newest change puts the check back when it fails.
    private var iconChanges = 0

    // MARK: Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)

        title = ProfileKitStrings.Appearance.title
        navigationItem.largeTitleDisplayMode = .never
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        setupLabels()
        setupTiles()
        setupIcons()
        view.addSubview(scrollView)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.pin
            .all()
        let margins = view.layoutMargins
        let width = view.bounds.width - margins.left - margins.right
        headerLabel.pin
            .top(16)
            .start(margins)
            .width(width)
            .sizeToFit(.width)
        detailLabel.pin
            .below(of: headerLabel)
            .start(margins)
            .width(width)
            .marginTop(4)
            .sizeToFit(.width)
        let tileFrames = RowLayout.frames(
            for: tiles,
            width: width,
            spacing: 12,
            stacks: traitCollection.preferredContentSizeCategory.isAccessibilityCategory,
            displayScale: traitCollection.displayScale,
        ) { tile, width in
            tile.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        }
        let tilesTop = detailLabel.frame.maxY + 20
        for (tile, frame) in zip(tiles, tileFrames) {
            tile.pin
                .top(tilesTop + frame.minY)
                .start(margins)
                .size(frame.size)
                .marginStart(frame.minX)
        }
        var previous: UIView = tiles.last ?? detailLabel
        if !iconRows.isEmpty {
            iconHeaderLabel.pin
                .below(of: previous)
                .start(margins)
                .width(width)
                .marginTop(36)
                .sizeToFit(.width)
            previous = iconHeaderLabel
            for row in iconRows {
                let height = row.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
                row.pin
                    .below(of: previous)
                    .start(margins)
                    .width(width)
                    .height(height)
                    .marginTop(row == iconRows.first ? 8 : 0)
                previous = row
            }
        }
        scrollView.contentSize = CGSize(width: view.bounds.width, height: previous.frame.maxY + 24)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Functions

    private func setupLabels() {
        headerLabel.text = ProfileKitStrings.Appearance.colorScheme
        headerLabel.font = .preferredFont(forTextStyle: .title3, weight: .semibold)
        headerLabel.adjustsFontForContentSizeCategory = true
        headerLabel.accessibilityTraits = .header
        detailLabel.text = ProfileKitStrings.Appearance.ColorScheme.detail
        detailLabel.numberOfLines = 0
        detailLabel.font = .preferredFont(forTextStyle: .body)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        scrollView.addSubview(headerLabel)
        scrollView.addSubview(detailLabel)
    }

    private func setupTiles() {
        for (tile, scheme) in zip(tiles, ColorScheme.allCases) {
            var configuration = UIButton.Configuration.plain()
            configuration.image = UIImage(systemName: scheme.symbolName)
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .title2)
            configuration.imagePlacement = .top
            configuration.imagePadding = 20
            configuration.title = scheme.title
            configuration.titleAlignment = .leading
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
                var attributes = $0
                attributes.font = .preferredFont(forTextStyle: .headline, compatibleWith: .current)
                return attributes
            }
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
            configuration.background.backgroundColor = .clear
            configuration.background.cornerRadius = 18
            tile.configuration = configuration
            tile.contentHorizontalAlignment = .leading
            tile.configurationUpdateHandler = { button in
                var configuration = button.configuration
                configuration?.baseForegroundColor = button.isSelected ? .label : .tertiaryLabel
                configuration?.background.strokeColor = button.isSelected ? .label : .tertiarySystemFill
                configuration?.background.strokeWidth = button.isSelected ? 2.5 : 1.5
                button.configuration = configuration
            }
            tile.isSelected = scheme == .current
            tile.addAction(UIAction { [weak self] _ in self?.choose(scheme) }, for: .primaryActionTriggered)
            scrollView.addSubview(tile)
        }
    }

    private func setupIcons() {
        guard !iconRows.isEmpty else {
            return
        }
        iconHeaderLabel.text = ProfileKitStrings.Appearance.appIcon
        iconHeaderLabel.font = .preferredFont(forTextStyle: .title3, weight: .semibold)
        iconHeaderLabel.adjustsFontForContentSizeCategory = true
        iconHeaderLabel.accessibilityTraits = .header
        scrollView.addSubview(iconHeaderLabel)
        for (row, icon) in zip(iconRows, AppIcon.allCases) {
            row.isSelected = icon == shownIcon
            row.addAction(UIAction { [weak self] _ in self?.choose(icon) }, for: .primaryActionTriggered)
            scrollView.addSubview(row)
        }
    }

    private func choose(_ icon: AppIcon) {
        guard icon != shownIcon else {
            return
        }
        select(icon)
        feedback.selectionChanged()
        iconChanges += 1
        let change = iconChanges
        Task { [weak self] in
            do {
                // The system tells the person with its own alert.
                try await UIApplication.shared.setAlternateIconName(icon.alternateIconName)
            } catch {
                guard let self else {
                    return
                }
                logger.error("App icon not changed: \(error.localizedDescription, privacy: .public)")
                guard change == iconChanges else {
                    return
                }
                select(AppIcon.current)
                ToastView.showFailure(ProfileKitStrings.Appearance.AppIcon.failed)
            }
        }
    }

    private func select(_ icon: AppIcon) {
        shownIcon = icon
        for (row, rowIcon) in zip(iconRows, AppIcon.allCases) {
            row.isSelected = rowIcon == icon
        }
    }

    private func choose(_ scheme: ColorScheme) {
        guard scheme != .current else {
            return
        }
        ColorScheme.current = scheme
        for (tile, tileScheme) in zip(tiles, ColorScheme.allCases) {
            tile.isSelected = tileScheme == scheme
        }
        feedback.selectionChanged()
        guard let scene = view.window?.windowScene else {
            return
        }
        for window in scene.windows {
            UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve) {
                scheme.apply(to: scene)
            }
        }
    }
}
