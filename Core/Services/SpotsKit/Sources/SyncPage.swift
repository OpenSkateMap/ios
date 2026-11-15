public import SpotModelKit

public struct SyncPage: Equatable, Sendable {
    public var items: [SpotIndex]
    public var tombstones: [String]
    public var nextCursor: Int
    public var hasMore: Bool
    public var resetRequired: Bool

    public init(items: [SpotIndex], tombstones: [String], nextCursor: Int, hasMore: Bool, resetRequired: Bool) {
        self.items = items
        self.tombstones = tombstones
        self.nextCursor = nextCursor
        self.hasMore = hasMore
        self.resetRequired = resetRequired
    }
}
