import AccountKit
import AppLinkKit
import AuthenticationServices
import ComponentKit
import FactoryKit
import PinLayout
import SafariServices
public import UIKit

// MARK: - SignInViewController

public final class SignInViewController: UIViewController {

    // MARK: Static Properties

    private static let margin: CGFloat = 24

    private static let headlineGap: CGFloat = 14

    private static let channelURL = URL(string: "https://www.youtube.com/@bataaard")!

    private static let footageAuthor = "Romain Batard"

    // MARK: Overridden Properties

    override public var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    // MARK: Computed Properties

    private var isPlaying: Bool {
        playbackChoice ?? (UIAccessibility.isVideoAutoplayEnabled && !UIAccessibility.isReduceMotionEnabled)
    }

    // MARK: Properties

    @Injected(\.authSession) private var authSession

    private let backdropView: SignInBackdropView
    private let wordmarkLabel = Label()
    private let footageCredit = UIButton(configuration: .plain())
    private let playbackButton = UIButton(configuration: .glass())
    private let headlineLabel = Label()
    private let subtitleLabel = Label()
    private let messageLabel = Label()
    private let appleButton = ASAuthorizationAppleIDButton(authorizationButtonType: .continue, authorizationButtonStyle: .white)
    private let progressView = UIView()
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let legalTextView = UITextView().softEdges()
    private var signInTask: Task<Void, Never>?
    private var playbackChoice: Bool?

    // MARK: Lifecycle

    public convenience init() {
        self.init(footage: .bundled)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupActions()
        setupObservers()
        renderPlayback()
    }

    override public func updateProperties() {
        super.updateProperties()

        let phase = authSession.phase
        showProgress(phase == .signingIn)
        switch phase {
        case .signedOut(let notice?):
            messageLabel.attributedText = Self.notice(notice.message, isFailure: notice.isFailure)

        case .signedOut(nil), .signingIn, .signedIn:
            messageLabel.text = nil
        }
        view.setNeedsLayout()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let safeArea = view.pin.safeArea
        let margin = Self.margin
        let sides = UIEdgeInsets(top: 0, left: safeArea.left + margin, bottom: 0, right: safeArea.right + margin)

        backdropView.pin
            .all()

        playbackButton.pin
            .top(safeArea.top + 4)
            .end(safeArea)
            .size(44)
            .marginEnd(margin - 10)
        wordmarkLabel.pin
            .vCenter(to: playbackButton.edge.vCenter)
            .start(sides)
            .sizeToFit()
        footageCredit.pin
            .below(of: wordmarkLabel)
            .start(sides)
            .marginTop(2 - 12)
            .sizeToFit()

        legalTextView.pin
            .bottom(max(safeArea.bottom, margin) + 4)
            .horizontally(sides)
            .sizeToFit(.width)
        appleButton.pin
            .above(of: legalTextView)
            .horizontally(sides)
            .height(52)
            .marginBottom(14)
        appleButton.cornerRadius = appleButton.bounds.height / 2
        progressView.pin
            .topStart(to: appleButton.anchor.topStart)
            .size(of: appleButton)
        progressView.layer.cornerRadius = appleButton.cornerRadius
        activityIndicator.pin
            .center()
            .sizeToFit()
        messageLabel.pin
            .bottom(view.bounds.height - appleButton.frame.minY + 10)
            .horizontally(sides)
            .sizeToFit(.width)
        let copyBottom = messageLabel.text?.isEmpty ?? true ? appleButton.frame.minY - 20 : messageLabel.frame.minY - 12
        subtitleLabel.pin
            .bottom(view.bounds.height - copyBottom)
            .horizontally(sides)
            .sizeToFit(.width)

        let room = CGSize(
            width: view.bounds.width - sides.left - sides.right,
            height: subtitleLabel.frame.minY - Self.headlineGap - (wordmarkLabel.frame.maxY + 32),
        )
        let pointSize = Self.headlinePointSize(
            fitting: room,
            maximum: UIFontMetrics(forTextStyle: .largeTitle).scaledValue(for: 76),
        )
        headlineLabel.isHidden = pointSize == nil
        if let pointSize {
            if headlineLabel.font.pointSize != pointSize {
                headlineLabel.attributedText = Self.headlineText(pointSize: pointSize)
            }
            // The label keeps the font's descent under the caps, so the gap is measured from the baseline.
            let descent = -Self.headlineFont(pointSize: pointSize).descender
            headlineLabel.pin
                .above(of: subtitleLabel)
                .horizontally(sides)
                .marginBottom(Self.headlineGap - descent)
                .sizeToFit(.width)
        }
        backdropView.textTop = headlineLabel.isHidden ? subtitleLabel.frame.minY : headlineLabel.frame.minY
    }

    init(footage: SignInFootage?) {
        backdropView = SignInBackdropView(footage: footage)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Static Functions

    private static func headlineFont(pointSize: CGFloat) -> UIFont {
        .systemFont(ofSize: pointSize, weight: .bold, width: .compressed)
    }

    private static func headlineText(pointSize: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = 0.86
        return NSAttributedString(
            string: SignInKitStrings.SignIn.headline,
            attributes: [
                .font: headlineFont(pointSize: pointSize),
                .kern: pointSize * 0.005,
                .paragraphStyle: paragraph,
            ],
        )
    }

    /// Failures keep white text: red text over the footage falls far below the 4.5:1 contrast small text needs.
    private static func notice(_ message: String, isFailure: Bool) -> NSAttributedString {
        let font = UIFont.preferredFont(forTextStyle: .footnote)
        let text = NSMutableAttributedString()
        if isFailure, let symbol = UIImage(systemName: "exclamationmark.circle.fill")?
            .withTintColor(.systemRed, renderingMode: .alwaysOriginal)
            .withConfiguration(UIImage.SymbolConfiguration(font: font)) {
            text.append(NSAttributedString(attachment: NSTextAttachment(image: symbol)))
            text.append(NSAttributedString(string: " "))
        }
        text.append(NSAttributedString(string: message))
        text.addAttributes(
            [.font: font, .foregroundColor: isFailure ? UIColor.white : UIColor.secondaryLabel],
            range: NSRange(location: 0, length: text.length),
        )
        return text
    }

    private static func legalText() -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let string = SignInKitStrings.SignIn.legal(LegalPage.terms.title, LegalPage.privacy.title)
        let text = NSMutableAttributedString(
            string: string,
            attributes: [
                .font: UIFont.preferredFont(forTextStyle: .caption1),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
                .paragraphStyle: paragraph,
            ],
        )
        for page in [LegalPage.terms, .privacy] {
            if let range = string.range(of: page.title) {
                text.addAttribute(.link, value: page.url, range: NSRange(range, in: string))
            }
        }
        return text
    }

    /// Exactly twice the line height can drop the second line.
    private static func headlinePointSize(fitting room: CGSize, maximum: CGFloat) -> CGFloat? {
        func measure(_ pointSize: CGFloat) -> CGSize {
            headlineText(pointSize: pointSize).boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                context: nil,
            ).size
        }
        // SF tracks tighter as it grows, so the estimate from one size is checked at its own size and stepped down.
        let reference = measure(100)
        var pointSize = floor(min(maximum, 100 * room.width / reference.width, 100 * room.height / reference.height))
        while pointSize >= 34 {
            let size = measure(pointSize)
            if size.width <= room.width, size.height <= room.height {
                return pointSize
            }
            pointSize -= 1
        }
        return nil
    }

    // MARK: Functions

    private func setupViews() {
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black

        wordmarkLabel.text = "OpenSkateMap"
        wordmarkLabel.font = UIFontMetrics(forTextStyle: .subheadline)
            .scaledFont(for: .systemFont(ofSize: 15, weight: .semibold, width: .expanded), maximumPointSize: 22)
        wordmarkLabel.adjustsFontForContentSizeCategory = true
        wordmarkLabel.textColor = .white
        wordmarkLabel.accessibilityTraits = .header

        headlineLabel.numberOfLines = 0
        headlineLabel.textColor = .white
        headlineLabel.accessibilityLabel = SignInKitStrings.SignIn.A11y.headline

        subtitleLabel.text = SignInKitStrings.SignIn.subtitle
        subtitleLabel.font = .preferredFont(forTextStyle: .body)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        subtitleLabel.numberOfLines = 0

        messageLabel.font = .preferredFont(forTextStyle: .footnote)
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 2

        legalTextView.attributedText = Self.legalText()
        legalTextView.adjustsFontForContentSizeCategory = true
        legalTextView.linkTextAttributes = [
            .foregroundColor: UIColor.white.withAlphaComponent(0.85),
            .underlineStyle: NSUnderlineStyle.single.rawValue,
        ]
        legalTextView.isEditable = false
        legalTextView.isScrollEnabled = false
        legalTextView.showsVerticalScrollIndicator = false
        legalTextView.showsHorizontalScrollIndicator = false
        legalTextView.backgroundColor = .clear
        legalTextView.textContainerInset = .zero
        legalTextView.textContainer.lineFragmentPadding = 0
        legalTextView.delegate = self

        progressView.backgroundColor = .white
        progressView.alpha = 0
        progressView.isAccessibilityElement = true
        progressView.accessibilityLabel = SignInKitStrings.SignIn.A11y.signingIn
        activityIndicator.color = .black
        progressView.addSubview(activityIndicator)

        playbackButton.configuration?.cornerStyle = .capsule
        playbackButton.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
            textStyle: .footnote,
            scale: .medium,
        )

        var credit = UIButton.Configuration.plain()
        // Caption text, but a 44 pt touch area (HIG); the layout pulls it up by the inset.
        credit.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
        credit.attributedTitle = AttributedString(
            SignInKitStrings.SignIn.footageCredit(Self.footageAuthor),
            attributes: AttributeContainer([
                .font: UIFont.preferredFont(forTextStyle: .caption2),
                .foregroundColor: UIColor.white.withAlphaComponent(0.6),
            ]),
        )
        footageCredit.configuration = credit
        footageCredit.accessibilityLabel = SignInKitStrings.SignIn.A11y.footageCredit(Self.footageAuthor)
        footageCredit.accessibilityHint = SignInKitStrings.SignIn.A11y.footageCreditHint(Self.footageAuthor)
        footageCredit.isHidden = !backdropView.hasFootage
        playbackButton.isHidden = !backdropView.hasFootage

        for subview in [
            backdropView,
            wordmarkLabel,
            footageCredit,
            playbackButton,
            headlineLabel,
            subtitleLabel,
            messageLabel,
            appleButton,
            progressView,
            legalTextView,
        ] {
            view.addSubview(subview)
        }
    }

    private func setupActions() {
        playbackButton.addAction(UIAction { [weak self] _ in self?.togglePlayback() }, for: .primaryActionTriggered)
        appleButton.addTarget(self, action: #selector(signInWithApple), for: .touchUpInside)
        footageCredit.addAction(UIAction { [weak self] _ in
            self?.present(SFSafariViewController(url: Self.channelURL), animated: true)
        }, for: .primaryActionTriggered)
    }

    private func setupObservers() {
        for name in [
            UIAccessibility.videoAutoplayStatusDidChangeNotification,
            UIAccessibility.reduceMotionStatusDidChangeNotification,
        ] {
            NotificationCenter.default.addObserver(self, selector: #selector(renderPlayback), name: name, object: nil)
        }
    }

    private func showProgress(_ isSigningIn: Bool) {
        appleButton.isEnabled = !isSigningIn
        appleButton.accessibilityElementsHidden = isSigningIn
        progressView.isHidden = false
        if isSigningIn {
            activityIndicator.startAnimating()
        }
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState]) {
            self.progressView.alpha = isSigningIn ? 1 : 0
        } completion: { _ in
            if self.progressView.alpha == 0 {
                self.progressView.isHidden = true
                self.activityIndicator.stopAnimating()
            }
        }
    }

    @objc
    private func renderPlayback() {
        let isPlaying = isPlaying
        backdropView.isPlaying = isPlaying
        playbackButton.configuration?.image = UIImage(systemName: isPlaying ? "pause.fill" : "play.fill")
        playbackButton.accessibilityLabel = isPlaying ? SignInKitStrings.SignIn.A11y.pause : SignInKitStrings.SignIn.A11y.play
    }

    private func togglePlayback() {
        playbackChoice = !isPlaying
        renderPlayback()
    }

    @objc
    private func signInWithApple() {
        guard signInTask == nil else {
            return
        }
        signInTask = Task {
            await authSession.signInWithApple()
            signInTask = nil
        }
    }
}

// MARK: UITextViewDelegate

extension SignInViewController: UITextViewDelegate {
    public func textView(_: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        guard case .link(let url) = textItem.content else {
            return defaultAction
        }
        return UIAction { [weak self] _ in
            self?.present(SFSafariViewController(url: url), animated: true)
        }
    }
}
