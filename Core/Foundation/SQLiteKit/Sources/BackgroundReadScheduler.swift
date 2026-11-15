public import SQLiteData

// MARK: - BackgroundReadScheduler

/// For a fetch wrapper's `load(_:scheduler:)`. With sqlite-data's default scheduler a load first reads the new query
/// on the calling thread, the main actor, and drops that value before its own background read; this one starts the
/// observation in the background too. A wrapper made with its query keeps the default: that synchronous read is its
/// first value, and the screen's first frame.
public struct BackgroundReadScheduler: ValueObservationScheduler, Hashable {
    public init() { }

    public func immediateInitialValue() -> Bool {
        false
    }

    public func schedule(_ action: @escaping @Sendable () -> Void) {
        action()
    }
}

extension ValueObservationScheduler where Self == BackgroundReadScheduler {
    public static var backgroundRead: Self {
        BackgroundReadScheduler()
    }
}
