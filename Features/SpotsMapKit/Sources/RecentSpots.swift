import Foundation

struct RecentSpots {

    // MARK: Static Properties

    private static let key = "map.recentSpots"
    private static let limit = 20

    // MARK: Computed Properties

    var ids: [String] {
        defaults.stringArray(forKey: Self.key) ?? []
    }

    // MARK: Properties

    let defaults: UserDefaults

    // MARK: Lifecycle

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    // MARK: Functions

    func add(_ id: String) {
        defaults.set(Array(([id] + ids.filter { $0 != id }).prefix(Self.limit)), forKey: Self.key)
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
