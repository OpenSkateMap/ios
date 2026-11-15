public struct AccountEndHandler: Sendable {
    public static let none = AccountEndHandler { }

    public var run: @MainActor @Sendable () -> Void

    public init(run: @escaping @MainActor @Sendable () -> Void) {
        self.run = run
    }

}
