public import SQLiteData

// MARK: - SpotFilter

public struct SpotFilter: Equatable, Sendable {

    // MARK: Computed Properties

    public var isEmpty: Bool {
        kinds.isEmpty && conditions.isEmpty && obstacles.isEmpty
    }

    // MARK: Properties

    public var kinds: Set<SpotKind>
    public var conditions: Set<SpotCondition>
    public var obstacles: Set<String>
    /// A collection on the map, not one of the person's filters: `isEmpty` doesn't count it.
    public var spotIDs: Set<String>?

    // MARK: Lifecycle

    public init(kinds: Set<SpotKind> = [],
                conditions: Set<SpotCondition> = [],
                obstacles: Set<String> = [],
                spotIDs: Set<String>? = nil) {
        self.kinds = kinds
        self.conditions = conditions
        self.obstacles = obstacles
        self.spotIDs = spotIDs
    }

    // MARK: Functions

    public func matches(_ spot: SpotIndex) -> Bool {
        let tagged = Set(spot.obstacles.map { $0.lowercased() })
        return (kinds.isEmpty || kinds.contains(spot.kind))
            && (conditions.isEmpty || conditions.contains(spot.condition))
            && obstacles.allSatisfy { tagged.contains($0.lowercased()) }
            && spotIDs?.contains(spot.id) != false
    }
}

extension Where<SpotIndex> {
    public func matching(_ filter: SpotFilter) -> Self {
        var query = self
        if !filter.kinds.isEmpty {
            let kinds = filter.kinds.sorted { $0.rawValue < $1.rawValue }
            query = query.where { $0.kind.in(kinds) }
        }
        if !filter.conditions.isEmpty {
            let conditions = filter.conditions.sorted { $0.rawValue < $1.rawValue }
            query = query.where { $0.condition.in(conditions) }
        }
        if let spotIDs = filter.spotIDs {
            let ids = spotIDs.sorted()
            query = query.where { $0.id.in(ids) }
        }
        for obstacle in filter.obstacles.sorted() {
            query = query.where {
                $0.obstacles.jsonEach().where { $0.value.collate(.nocase).eq(obstacle) }.exists()
            }
        }
        return query
    }
}
