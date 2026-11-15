import Foundation

struct TopicChoices: Sendable {

    // MARK: Types

    private struct Row: Codable {
        var slug: String
        var name: String
        var description: String?
        var isOn: Bool
    }

    // MARK: Computed Properties

    private var defaults: UserDefaults {
        suiteName.flatMap(UserDefaults.init(suiteName:)) ?? .standard
    }

    // MARK: Properties

    /// A name, not a `UserDefaults`, which isn't `Sendable`.
    private let suiteName: String?

    // MARK: Lifecycle

    init(suiteName: String? = nil) {
        self.suiteName = suiteName
    }

    // MARK: Functions

    func load(for subscriberID: String) -> [NotificationTopic]? {
        guard let data = defaults.data(forKey: key(subscriberID)),
              let rows = try? JSONDecoder().decode([Row].self, from: data) else {
            return nil
        }
        return NotificationTopic.ordered(rows.map { ($0.slug, $0.name, $0.description, $0.isOn) })
    }

    func save(_ topics: [NotificationTopic], for subscriberID: String) {
        let rows = topics.filter(\.isAvailable).map { Row(slug: $0.id, name: $0.title, description: $0.detail, isOn: $0.isOn) }
        defaults.set(try? JSONEncoder().encode(rows), forKey: key(subscriberID))
    }

    func remove(for subscriberID: String) {
        defaults.removeObject(forKey: key(subscriberID))
    }

    private func key(_ subscriberID: String) -> String {
        "notifications.topics.\(subscriberID)"
    }
}
