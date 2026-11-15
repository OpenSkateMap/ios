public import UIKit

/// A pull to refresh that reads as one: the spinner stays at least 0.5 s, however fast the answer, and ends only once
/// the finger lifts, since ending it mid-pull drops its inset and the pull snaps back. The scroll view's delegate calls
/// `fingerLifted()` from `scrollViewDidEndDragging`.
public final class PullToRefreshControl: UIRefreshControl {

    // MARK: Static Properties

    private static let minimumSpinner = Duration.milliseconds(500)

    // MARK: Properties

    private let refresh: @MainActor () async -> (@MainActor () -> Void)?
    private var endsOnRelease = false

    // MARK: Lifecycle

    /// `refresh` returns what to show once the spinner's minimum has passed (a failure toast), or nil.
    public init(refresh: @escaping @MainActor () async -> (@MainActor () -> Void)?) {
        self.refresh = refresh
        super.init()
        addAction(UIAction { [weak self] _ in self?.pulled() }, for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Functions

    /// There, not from the pan gesture's target: by the time that runs the scroll view is already settling onto the
    /// refresh inset, and keeps it after the spinner ends.
    public func fingerLifted() {
        guard endsOnRelease else {
            return
        }
        endsOnRelease = false
        endRefreshing()
    }

    private func pulled() {
        let started = ContinuousClock.now
        Task { [weak self, refresh] in
            let then = await refresh()
            let remaining = Self.minimumSpinner - (ContinuousClock.now - started)
            if remaining > .zero {
                try? await Task.sleep(for: remaining)
            }
            self?.finish()
            then?()
        }
    }

    private func finish() {
        guard isRefreshing else {
            return
        }
        if (superview as? UIScrollView)?.isDragging == true {
            endsOnRelease = true
        } else {
            endRefreshing()
        }
    }
}
