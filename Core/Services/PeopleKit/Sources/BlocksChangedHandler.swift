public struct BlocksChangedHandler: Sendable {
    public static let none = BlocksChangedHandler { }

    public var run: @MainActor @Sendable () async -> Void

    public init(run: @escaping @MainActor @Sendable () async -> Void) {
        self.run = run
    }
}
