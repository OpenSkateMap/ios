import UIKit

/// VoiceOver reads the row as its switch.
final class SwitchCell: UICollectionViewListCell {

    // MARK: Overridden Properties

    override var accessibilityTraits: UIAccessibilityTraits {
        get { toggle.accessibilityTraits }
        set { }
    }

    override var accessibilityValue: String? {
        get { toggle.accessibilityValue }
        set { }
    }

    // MARK: Properties

    var onChange: ((Bool) -> Void)?

    private let toggle = UISwitch()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        isAccessibilityElement = true
        toggle.addAction(UIAction { [weak self] _ in
            guard let self else {
                return
            }
            onChange?(toggle.isOn)
        }, for: .valueChanged)
        accessories = [.customView(configuration: .init(customView: toggle, placement: .trailing()))]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func accessibilityActivate() -> Bool {
        guard toggle.isEnabled else {
            return false
        }
        toggle.setOn(!toggle.isOn, animated: true)
        toggle.sendActions(for: .valueChanged)
        return true
    }

    // MARK: Functions

    func show(_ content: UIListContentConfiguration, isOn: Bool, isEnabled: Bool = true) {
        contentConfiguration = content
        if toggle.isOn != isOn {
            toggle.setOn(isOn, animated: window != nil)
        }
        toggle.isEnabled = isEnabled
        accessibilityLabel = content.text
        accessibilityHint = content.secondaryText
    }
}
