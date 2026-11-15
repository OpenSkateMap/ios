import AppLinkKit
import ComponentKit
import PinLayout
public import UIKit

// MARK: - OnboardingViewController

public final class OnboardingViewController: UIViewController {

    // MARK: Static Properties

    private static let margin: CGFloat = 20

    // MARK: Properties

    private let onContinue: () -> Void
    private let scrollView = UIScrollView().softEdges()
    private let versionLabel = Label()
    private let titleLabel = Label()
    private let subtitleLabel = Label()
    private let cards = [
        WelcomeCardView(
            screenshot: OnboardingKitAsset.welcomeMap,
            title: OnboardingKitStrings.Welcome.Map.title,
            detail: OnboardingKitStrings.Welcome.Map.detail,
        ),
        WelcomeCardView(
            screenshot: OnboardingKitAsset.welcomePage,
            title: OnboardingKitStrings.Welcome.Page.title,
            detail: OnboardingKitStrings.Welcome.Page.detail,
        ),
        WelcomeCardView(
            screenshot: OnboardingKitAsset.welcomeNewSpot,
            title: OnboardingKitStrings.Welcome.NewSpot.title,
            detail: OnboardingKitStrings.Welcome.NewSpot.detail,
        ),
    ]
    private let privacyLabel = Label()
    private let shareButton = UIButton(configuration: .plain())
    private let closeButton = UIButton(configuration: .glassIcon("xmark"))
    private var hasPlayedEntrance = false

    // MARK: Lifecycle

    public init(onContinue: @escaping () -> Void) {
        self.onContinue = onContinue
        super.init(nibName: nil, bundle: nil)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupActions()
    }

    override public func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        playEntranceOnce()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let safeArea = view.pin.safeArea
        closeButton.pin
            .top(safeArea.top + 8)
            .end(safeArea)
            .size(44)
            .marginEnd(16)
        scrollView.pin
            .all()

        let width = min(view.bounds.width - safeArea.left - safeArea.right - 2 * Self.margin, 560)
        let inset = (view.bounds.width - width) / 2
        versionLabel.pin
            .start(inset)
            .end(to: closeButton.edge.start)
            .marginEnd(8)
            .sizeToFit(.width)
        versionLabel.pin
            .top(closeButton.frame.midY - versionLabel.frame.height / 2)
        titleLabel.font = Self.titleFont(fitting: width, text: titleLabel.text ?? "", traits: traitCollection)
        titleLabel.pin
            .below(of: versionLabel)
            .start(inset)
            .width(width)
            .marginTop(20)
            .sizeToFit(.width)
        subtitleLabel.pin
            .below(of: titleLabel)
            .start(inset)
            .width(width)
            .marginTop(8)
            .sizeToFit(.width)
        var previous: UIView = subtitleLabel
        for card in cards {
            card.pin
                .below(of: previous)
                .start(inset)
                .width(width)
                .marginTop(previous === subtitleLabel ? 32 : 40)
                .sizeToFit(.width)
            previous = card
        }
        privacyLabel.pin
            .below(of: previous)
            .start(inset)
            .width(width)
            .marginTop(40)
            .sizeToFit(.width)
        shareButton.pin
            .below(of: privacyLabel)
            .hCenter()
            .marginTop(16)
            .sizeToFit()
        scrollView.contentSize = CGSize(width: view.bounds.width, height: shareButton.frame.maxY + 16)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override public func accessibilityPerformEscape() -> Bool {
        finish()
        return true
    }

    // MARK: Static Functions

    /// Shrinks the large title only as far as its longest word needs to fit on one line.
    private static func titleFont(fitting width: CGFloat, text: String, traits: UITraitCollection) -> UIFont {
        let font = UIFont.preferredFont(forTextStyle: .largeTitle, weight: .bold, compatibleWith: traits)
        let widest = text.split(whereSeparator: \.isWhitespace)
            .map { word in
                TextLayout(text: NSAttributedString(string: String(word), attributes: [.font: font]), numberOfLines: 1)
                    .size(fitting: 0)
                    .width
            }
            .max() ?? 0
        guard widest > width, widest > 0 else {
            return font
        }
        return font.withSize((font.pointSize * width / widest).rounded(.down))
    }

    // MARK: Functions

    private func setupViews() {
        view.backgroundColor = .systemBackground
        scrollView.alwaysBounceVertical = true
        view.addSubview(scrollView)

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        versionLabel.text = OnboardingKitStrings.Welcome.version(version)
        versionLabel.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        versionLabel.adjustsFontForContentSizeCategory = true
        versionLabel.adjustsFontSizeToFitWidth = true
        versionLabel.minimumScaleFactor = 0.5
        versionLabel.textColor = .secondaryLabel

        titleLabel.text = OnboardingKitStrings.Welcome.title
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityTraits = .header

        subtitleLabel.text = OnboardingKitStrings.Welcome.subtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = .secondaryLabel
        subtitleLabel.numberOfLines = 0

        privacyLabel.text = OnboardingKitStrings.Welcome.privacy
        privacyLabel.font = .preferredFont(forTextStyle: .footnote)
        privacyLabel.adjustsFontForContentSizeCategory = true
        privacyLabel.textColor = .secondaryLabel
        privacyLabel.textAlignment = .center
        privacyLabel.numberOfLines = 0

        shareButton.configuration?.title = OnboardingKitStrings.Welcome.share
        shareButton.configuration?.image = UIImage(systemName: "paperplane.fill")
        shareButton.configuration?.imagePadding = 6
        shareButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .subheadline)
        shareButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
            return attributes
        }

        closeButton.accessibilityLabel = OnboardingKitStrings.Welcome.close

        for subview in [versionLabel, titleLabel, subtitleLabel] + cards + [privacyLabel, shareButton] {
            scrollView.addSubview(subview)
        }
        view.addSubview(closeButton)
    }

    private func setupActions() {
        closeButton.addAction(UIAction { [weak self] _ in self?.finish() }, for: .primaryActionTriggered)
        shareButton.addAction(UIAction { [weak self] _ in self?.shareApp() }, for: .primaryActionTriggered)
    }

    private func shareApp() {
        let share = UIActivityViewController(
            activityItems: [URL(string: "https://\(AppLink.host)")!],
            applicationActivities: nil,
        )
        share.popoverPresentationController?.sourceView = shareButton
        present(share, animated: true)
    }

    private func finish() {
        onContinue()
        dismiss(animated: true)
    }

    private func playEntranceOnce() {
        guard !hasPlayedEntrance else {
            return
        }
        hasPlayedEntrance = true
        let views: [UIView] = [versionLabel, titleLabel, subtitleLabel] + cards
        let rises = !UIAccessibility.isReduceMotionEnabled
        for (index, view) in views.enumerated() {
            view.alpha = 0
            if rises {
                view.transform = CGAffineTransform(translationX: 0, y: 24)
            }
            UIView.animate(springDuration: 0.6, bounce: 0.15, delay: 0.1 + Double(index) * 0.06) {
                view.alpha = 1
                view.transform = .identity
            }
        }
    }
}

extension OnboardingViewController {
    public static func presentWelcomeIfNeeded(over presenter: UIViewController,
                                              store: OnboardingStore,
                                              onClose: @escaping () -> Void) {
        guard !store.isWelcomeSeen(), presenter.presentedViewController == nil else {
            return
        }
        let welcome = OnboardingViewController {
            store.setWelcomeSeen(true)
            onClose()
        }
        welcome.modalPresentationStyle = .fullScreen
        presenter.present(welcome, animated: true)
    }
}
