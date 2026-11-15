import AppLinkKit
import Observation

@Observable
final class AppLinks {

    // MARK: Properties

    private(set) var pending: AppLink?

    // MARK: Functions

    func open(_ link: AppLink) {
        pending = link
    }

    func take() -> AppLink? {
        defer { pending = nil }
        return pending
    }
}
