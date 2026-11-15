import ComponentKit
import PinLayout
import UIKit

final class PhotoCreditEditorView: UIView {

    // MARK: Types

    /// A photo of the form (with Make Cover and Remove Photo), or one step of going through a pick.
    enum Subject {
        case photo(isCover: Bool)
        case step
    }

    // MARK: Properties

    private(set) var draft: NewSpotForm.Credit
    var onChange: (() -> Void)?
    var onMakeCover: (() -> Void)?
    var onRemove: (() -> Void)?

    private let mineRow = FormRowButton(glyph: nil, title: ContributeKitStrings.PhotoCredit.mine, accessory: .none)
    private let someoneElseRow = FormRowButton(
        glyph: nil,
        title: ContributeKitStrings.PhotoCredit.someoneElse,
        accessory: .none,
    )
    private let nameRow = FormFieldRowView(placeholder: ContributeKitStrings.PhotoCredit.namePlaceholder)
    private let permissionRow = FormToggleRowView(title: ContributeKitStrings.PhotoCredit.permission)
    private let choiceCard: FormCardView
    private let someoneElseCard: FormCardView
    private let hintLabel = FormText.hint(ContributeKitStrings.PhotoCredit.hint)
    private let makeCoverButton = UIButton(configuration: .secondaryCapsule(title: ContributeKitStrings.PhotoCredit.makeCover))
    private let removeButton = UIButton(configuration: .secondaryCapsule(title: ContributeKitStrings.PhotoCredit.remove))

    // MARK: Lifecycle

    init(credit: NewSpotForm.Credit, for subject: Subject) {
        draft = credit
        choiceCard = FormCardView(rows: [mineRow, someoneElseRow])
        someoneElseCard = FormCardView(rows: [nameRow, permissionRow])
        super.init(frame: .zero)
        mineRow.addAction(UIAction { [weak self] _ in self?.choose(mine: true) }, for: .primaryActionTriggered)
        someoneElseRow.addAction(UIAction { [weak self] _ in self?.choose(mine: false) }, for: .primaryActionTriggered)
        nameRow.textField.text = credit.name
        nameRow.textField.autocorrectionType = .no
        nameRow.textField.autocapitalizationType = .none
        nameRow.textField.accessibilityLabel = ContributeKitStrings.PhotoCredit.A11y.name
        nameRow.textField.addAction(UIAction { [weak self] _ in self?.nameChanged() }, for: .editingChanged)
        permissionRow.toggle.isOn = credit.hasPermission
        permissionRow.toggle.addAction(UIAction { [weak self] _ in self?.permissionChanged() }, for: .valueChanged)
        makeCoverButton.configuration?.image = UIImage(systemName: "rectangle.portrait.on.rectangle.portrait")
        makeCoverButton.configuration?.imagePadding = 6
        if case .photo(let isCover) = subject {
            makeCoverButton.isHidden = isCover
        } else {
            makeCoverButton.isHidden = true
            removeButton.isHidden = true
        }
        makeCoverButton.addAction(UIAction { [weak self] _ in self?.onMakeCover?() }, for: .primaryActionTriggered)
        removeButton.configuration?.image = UIImage(systemName: "trash")
        removeButton.configuration?.imagePadding = 6
        removeButton.configuration?.baseForegroundColor = .systemRed
        removeButton.addAction(UIAction { [weak self] _ in self?.onRemove?() }, for: .primaryActionTriggered)
        for view in [choiceCard, someoneElseCard, hintLabel, makeCoverButton, removeButton] {
            addSubview(view)
        }
        update()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
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

    /// Another photo's credit in the same views, so going from photo to photo changes nothing but what they show.
    func show(_ credit: NewSpotForm.Credit) {
        draft = credit
        nameRow.textField.text = credit.name
        permissionRow.toggle.isOn = credit.hasPermission
        if credit.takenBySubmitter {
            nameRow.textField.resignFirstResponder()
        }
        update()
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        choiceCard.pin
            .top()
            .start()
            .width(width)
            .sizeToFit(.width)
        var bottom = choiceCard.frame.maxY
        if !someoneElseCard.isHidden {
            someoneElseCard.pin
                .top(bottom + 12)
                .start()
                .width(width)
                .sizeToFit(.width)
            hintLabel.pin
                .below(of: someoneElseCard)
                .horizontally(16)
                .marginTop(8)
                .sizeToFit(.width)
            bottom = hintLabel.frame.maxY
        }
        let buttons = [makeCoverButton, removeButton].filter { !$0.isHidden }
        let sideBySide = (width - CGFloat(buttons.count - 1) * 10) / CGFloat(buttons.count)
        let fits = buttons.allSatisfy {
            $0.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: 52)).width <= sideBySide
        }
        let buttonWidth = fits ? sideBySide : width
        let height = buttons.map { $0.capsuleHeight(fitting: buttonWidth) }.max() ?? 0
        var origin = CGPoint(x: 0, y: bottom + 16)
        for button in buttons {
            button.pin
                .top(origin.y)
                .start(origin.x)
                .width(buttonWidth)
                .height(height)
            if fits {
                origin.x += buttonWidth + 10
            } else {
                origin.y += height + 10
            }
        }
        return buttons.last?.frame.maxY ?? bottom
    }

    private func choose(mine: Bool) {
        draft.takenBySubmitter = mine
        update()
        if !mine, draft.name.isEmpty {
            nameRow.textField.becomeFirstResponder()
        }
    }

    private func nameChanged() {
        draft.name = nameRow.textField.text ?? ""
        onChange?()
    }

    private func permissionChanged() {
        draft.hasPermission = permissionRow.toggle.isOn
        onChange?()
    }

    private func update() {
        let mine = draft.takenBySubmitter
        mineRow.glyph = UIImage(systemName: mine ? "checkmark.circle.fill" : "circle")
        someoneElseRow.glyph = UIImage(systemName: mine ? "circle" : "checkmark.circle.fill")
        mineRow.accessibilityTraits = mine ? [.button, .selected] : .button
        someoneElseRow.accessibilityTraits = mine ? .button : [.button, .selected]
        someoneElseCard.isHidden = mine
        hintLabel.isHidden = mine
        setNeedsLayout()
        onChange?()
    }
}
