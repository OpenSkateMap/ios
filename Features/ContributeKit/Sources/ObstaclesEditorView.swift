import ComponentKit
import SpotModelKit
import UIKit

final class ObstaclesEditorView: UIView {

    // MARK: Properties

    private(set) var selection: Set<String>

    private var chips: ToggleChipsView?

    // MARK: Lifecycle

    init(selection: Set<String>) {
        self.selection = selection
        super.init(frame: .zero)
        let chips = ToggleChipsView(
            values: SpotObstacle.choices(including: selection),
            title: SpotObstacle.title(of:),
            isSelected: { selection.contains($0) },
            onToggle: { [weak self] in self?.toggle($0) },
        )
        self.chips = chips
        addSubview(chips)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        chips?.frame = bounds
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        chips?.sizeThatFits(size) ?? .zero
    }

    // MARK: Functions

    private func toggle(_ obstacle: String) {
        if selection.contains(obstacle) {
            selection.remove(obstacle)
        } else {
            selection.insert(obstacle)
        }
    }
}
