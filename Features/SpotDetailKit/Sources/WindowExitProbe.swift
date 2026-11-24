import UIKit

/// Tells when the view it's added to leaves the window. A sheet presented over another reaches the presenter through
/// no public callback when it goes (swiped down, or closed from inside), so the spot sheet leaves one of these in it.
final class WindowExitProbe: UIView {

    // MARK: Properties

    private let onExit: () -> Void

    // MARK: Lifecycle

    init(onExit: @escaping () -> Void) {
        self.onExit = onExit
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func didMoveToWindow() {
        super.didMoveToWindow()

        if window == nil {
            onExit()
        }
    }
}
