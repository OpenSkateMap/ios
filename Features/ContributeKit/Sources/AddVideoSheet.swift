import ComponentKit
import ContributionsKit
import FactoryKit
import ImageKit
import PinLayout
import SpotModelKit
public import UIKit

// MARK: - AddVideoSheet

public enum AddVideoSheet {
    public static func make(spotID: String, spotTitle: String) -> UIViewController {
        let content = AddVideoContentView(
            model: AddVideoModel(checker: Container.shared.videoLinkChecker()),
            loader: Container.shared.imageLoader(),
        )
        let session = Container.shared.contributionsSession()
        let sheet = OptionSheetViewController(
            title: ContributeKitStrings.AddVideo.title,
            message: ContributeKitStrings.AddVideo.message(spotTitle),
            content: content,
            tint: nil,
            confirmTitle: ContributeKitStrings.AddVideo.send,
            failureTitle: ContributeKitStrings.AddVideo.saveFailed,
        ) { [content] in
            guard let link = content.link else {
                return
            }
            try await session.addVideo(link, to: spotID, caption: content.caption)
            UINotificationFeedbackGenerator(view: content).notificationOccurred(.success)
            Task { await ToastView().show(.icon(predefinedIcon: .success, title: ContributeKitStrings.AddVideo.sent)) }
        }
        content.onChange = { [weak sheet, weak content] in
            sheet?.isConfirmEnabled = content?.link != nil
            sheet?.contentDidChange()
        }
        sheet.isConfirmEnabled = false
        return sheet
    }
}

// MARK: - AddVideoContentView

final class AddVideoContentView: UIView {

    // MARK: Computed Properties

    var link: VideoLink? {
        model.sendableLink
    }

    var caption: String {
        captionRow.textField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var linkText: String {
        get { linkRow.textField.text ?? "" }
        set {
            linkRow.textField.text = newValue
            model.setLinkText(newValue)
        }
    }

    // MARK: Properties

    var onChange: (() -> Void)?

    let model: AddVideoModel

    private let linkRow = FormFieldRowView(placeholder: ContributeKitStrings.AddVideo.linkPlaceholder)
    private let captionRow = FormFieldRowView(placeholder: ContributeKitStrings.AddVideo.caption)
    private let fields: FormCardView
    private let preview = VideoLinkPreviewView()
    private let problemLabel = Label()
    private let loader: ImageLoader
    private var shownState: AddVideoModel.LinkState?

    // MARK: Lifecycle

    init(model: AddVideoModel, loader: ImageLoader) {
        self.model = model
        self.loader = loader
        fields = FormCardView(rows: [linkRow, captionRow])
        super.init(frame: .zero)
        setupViews()
        setupActions()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateProperties() {
        super.updateProperties()

        let state = model.state
        guard state != shownState else {
            return
        }
        shownState = state
        show(state)
        setNeedsLayout()
        onChange?()
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    private func setupViews() {
        linkRow.textField.runsLeftToRight()
        linkRow.textField.keyboardType = .URL
        linkRow.textField.textContentType = .URL
        linkRow.textField.autocapitalizationType = .none
        linkRow.textField.autocorrectionType = .no
        linkRow.textField.accessibilityLabel = ContributeKitStrings.AddVideo.A11y.link
        linkRow.textField.accessibilityHint = ContributeKitStrings.AddVideo.A11y.linkHint
        captionRow.textField.accessibilityLabel = ContributeKitStrings.AddVideo.caption
        captionRow.textField.accessibilityHint = ContributeKitStrings.AddVideo.A11y.captionHint
        problemLabel.font = .preferredFont(forTextStyle: .footnote)
        problemLabel.adjustsFontForContentSizeCategory = true
        problemLabel.textColor = .systemRed
        problemLabel.numberOfLines = 0
        problemLabel.isHidden = true
        preview.isHidden = true
        for view in [fields, preview, problemLabel] {
            addSubview(view)
        }
    }

    private func setupActions() {
        linkRow.textField.addAction(UIAction { [weak self] _ in
            guard let self else {
                return
            }
            model.setLinkText(linkText, isEditing: true)
        }, for: .editingChanged)
        linkRow.textField.addAction(UIAction { [weak self] _ in
            guard let self else {
                return
            }
            model.setLinkText(linkText)
        }, for: .editingDidEnd)
        captionRow.textField.addAction(UIAction { [weak self] _ in self?.limitCaption() }, for: .editingChanged)
    }

    private func show(_ state: AddVideoModel.LinkState) {
        switch state {
        case .empty, .unfinished:
            preview.isHidden = true
            problemLabel.text = nil

        case .invalid:
            preview.isHidden = true
            problemLabel.text = ContributeKitStrings.AddVideo.invalid

        case .checking(let link):
            preview.show(link, status: nil, loader: loader)
            preview.isHidden = false
            problemLabel.text = nil

        case .checked(_, .unavailable):
            preview.isHidden = true
            problemLabel.text = ContributeKitStrings.AddVideo.unavailable

        case .checked(let link, let status):
            preview.show(link, status: status, loader: loader)
            preview.isHidden = false
            problemLabel.text = nil
        }
        problemLabel.isHidden = problemLabel.text == nil
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        fields.pin
            .top()
            .start()
            .width(width)
            .height(fields.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
        var bottom = fields.frame.maxY
        if !preview.isHidden {
            preview.pin
                .top(bottom + 16)
                .start()
                .width(width)
                .height(VideoLinkPreviewView.height)
            bottom = preview.frame.maxY
        }
        if !problemLabel.isHidden {
            problemLabel.pin
                .top(bottom + 12)
                .start()
                .width(width)
                .sizeToFit(.width)
            bottom = problemLabel.frame.maxY
        }
        return bottom
    }

    /// The server keeps 120 characters.
    private func limitCaption() {
        if let text = captionRow.textField.text, text.count > 120 {
            captionRow.textField.text = String(text.prefix(120))
        }
    }
}

// MARK: - VideoLinkPreviewView

private final class VideoLinkPreviewView: UIView {

    // MARK: Static Properties

    static let height: CGFloat = 72

    // MARK: Properties

    private let thumbnailView = VideoThumbnailView()
    private let titleLabel = Label()
    private let linkLabel = Label()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        linkLabel.font = .preferredFont(forTextStyle: .footnote)
        linkLabel.adjustsFontForContentSizeCategory = true
        linkLabel.textColor = .secondaryLabel
        linkLabel.lineBreakMode = .byTruncatingMiddle
        for view in [thumbnailView, titleLabel, linkLabel] {
            addSubview(view)
        }
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        thumbnailView.pin
            .vCenter()
            .start()
            .size(VideoThumbnailView.size)
        titleLabel.pin
            .top(16)
            .after(of: thumbnailView)
            .end()
            .marginStart(12)
            .sizeToFit(.width)
        linkLabel.pin
            .below(of: titleLabel, aligned: .start)
            .end()
            .marginTop(2)
            .sizeToFit(.width)
    }

    // MARK: Functions

    func show(_ link: VideoLink, status: VideoLinkStatus?, loader: ImageLoader) {
        let address = link.url.absoluteString.replacingOccurrences(of: "https://", with: "")
        switch status {
        case .available(let title, let author):
            titleLabel.text = title
            linkLabel.text = [link.provider.title, author].compactMap(\.self).joined(separator: " · ")

        case nil:
            titleLabel.text = link.provider == .youtube
                ? ContributeKitStrings.AddVideo.Preview.youtube
                : ContributeKitStrings.AddVideo.Preview.instagram
            linkLabel.text = ContributeKitStrings.AddVideo.Preview.checking

        case .unknown, .unavailable:
            titleLabel.text = link.provider == .youtube
                ? ContributeKitStrings.AddVideo.Preview.youtube
                : ContributeKitStrings.AddVideo.Preview.instagram
            linkLabel.text = address
        }
        accessibilityLabel = [titleLabel.text, linkLabel.text].compactMap(\.self).joined(separator: ", ")
        thumbnailView.show(link.provider, thumbnail: link.thumbnailURL, loader: loader)
        setNeedsLayout()
    }
}
