public import FactoryKit

// MARK: - AppLinkOpener

nonisolated public struct AppLinkOpener: Sendable {
    public static let none = AppLinkOpener { _ in }

    public var open: @MainActor @Sendable (_ link: AppLink) -> Void

    public init(open: @escaping @MainActor @Sendable (_ link: AppLink) -> Void) {
        self.open = open
    }
}

extension Container {
    public var appLinkOpener: Factory<AppLinkOpener> {
        self { .none }
    }
}
