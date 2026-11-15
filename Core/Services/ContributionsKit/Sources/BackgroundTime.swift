// MARK: - BackgroundTime

public struct BackgroundTime: Sendable {
    public static let none = BackgroundTime { work, _ in await work() }

    private let body: @Sendable (_ work: @escaping @Sendable () async -> Void,
                                 _ expired: @escaping @Sendable () async -> Void) async -> Void
    private let shownBody: (@Sendable (_ title: String,
                                       _ work: @escaping @Sendable (BackgroundProgress) async -> Void,
                                       _ expired: @escaping @Sendable () async -> Void) async -> Void)?

    public init(run body: @escaping @Sendable (_ work: @escaping @Sendable () async -> Void,
                                               _ expired: @escaping @Sendable () async -> Void) async -> Void,
                runShown shownBody: (@Sendable (_ title: String,
                                                _ work: @escaping @Sendable (BackgroundProgress) async -> Void,
                                                _ expired: @escaping @Sendable () async -> Void) async -> Void)? = nil) {
        self.body = body
        self.shownBody = shownBody
    }

    /// `expired` runs if the time is up before `work` returns; `work` should stop soon after.
    public func run(_ work: @escaping @Sendable () async -> Void, expired: @escaping @Sendable () async -> Void) async {
        await body(work, expired)
    }

    /// The same for work a person started: the system can show `title` with what `work` reports, and keep it going
    /// after they leave the app. `expired` also runs when they cancel it there.
    public func run(shownAs title: String,
                    _ work: @escaping @Sendable (BackgroundProgress) async -> Void,
                    expired: @escaping @Sendable () async -> Void) async {
        guard let shownBody else {
            return await body({ await work(.none) }, expired)
        }
        await shownBody(title, work, expired)
    }
}

// MARK: - BackgroundProgress

/// How far shown work has got: `completed` of `total` steps, and a line saying so.
public struct BackgroundProgress: Sendable {
    public static let none = BackgroundProgress { _, _, _ in }

    private let body: @Sendable (_ completed: Int, _ total: Int, _ subtitle: String) -> Void

    public init(report body: @escaping @Sendable (_ completed: Int, _ total: Int, _ subtitle: String) -> Void) {
        self.body = body
    }

    func report(completed: Int, of total: Int, subtitle: String) {
        body(completed, total, subtitle)
    }
}
