import UIKit

final class ToastWindow: UIWindow {

    // MARK: Static Properties

    static let shared: ToastWindow = {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        // A toast is shown from a screen, so a scene is connected by then.
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            preconditionFailure("A toast needs a connected window scene")
        }
        return ToastWindow(windowScene: scene)
    }()

    // MARK: Overridden Properties

    override var next: UIResponder? {
        nil
    }

    override var canBecomeFirstResponder: Bool {
        false
    }

    // MARK: Properties

    /// Shown toasts, newest first.
    private var stack = [ToastView]()

    // MARK: Lifecycle

    override init(windowScene: UIWindowScene) {
        super.init(windowScene: windowScene)

        let rootViewController = UIViewController()
        rootViewController.view.isUserInteractionEnabled = false
        rootViewController.view.backgroundColor = .clear
        self.rootViewController = rootViewController
        backgroundColor = .clear
        windowLevel = .alert + 1
        syncToKeyWindow()
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func becomeFirstResponder() -> Bool {
        false
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        syncToKeyWindow()
        for view in subviews {
            view.frame = bounds
        }
    }

    /// Touches pass through to the app, except on a toast's own button (Undo).
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        for toast in stack {
            if let button = toast.hitTest(convert(point, to: toast), with: event) {
                return button
            }
        }
        return nil
    }

    // MARK: Functions

    func updateVisibility() {
        syncToKeyWindow()
        isHidden = !subviews.contains { $0 is ToastView && !$0.isHidden }
    }

    func push(_ toast: ToastView) {
        stack.removeAll { $0 === toast }
        stack.insert(toast, at: 0)
        bringSubviewToFront(toast)
        updateVisibility()
        restack()
    }

    func remove(_ toast: ToastView) {
        stack.removeAll { $0 === toast }
        restack()
    }

    func restack() {
        let frontSize = stack.first?.capsuleSize
        for (depth, toast) in stack.enumerated() {
            toast.place(depth: depth, frontSize: frontSize)
        }
    }

    func isShowing(_ text: String) -> Bool {
        stack.contains { $0.shownText == text }
    }

    func hideAllCompletedToasts() {
        for case let toast as ToastView in subviews {
            toast.update(with: .hidden)
        }
    }

    private func syncToKeyWindow() {
        let keyWindow = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow && !($0 is ToastWindow) }
        guard let keyWindow else {
            return
        }
        windowScene = keyWindow.windowScene
        frame = keyWindow.bounds
        rootViewController?.view.frame = bounds
    }
}
