import CustomDump
import Foundation
import Testing
@testable import NotificationsKit

@Suite(.timeLimit(.minutes(1)))
struct TopicChoicesTests {
    @Test
    func `each subscriber's choices come back as saved until they're removed`() throws {
        let suite = "TopicChoicesTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let choices = TopicChoices(suiteName: suite)
        let topics = NotificationTopic.ordered([
            (slug: "review-results", name: "Review results", description: nil, isOn: true),
            (slug: "new-spots", name: "New spots", description: nil, isOn: false),
        ])

        expectNoDifference(choices.load(for: "rider"), nil)
        choices.save(topics, for: "rider")
        expectNoDifference(choices.load(for: "rider"), topics)
        expectNoDifference(choices.load(for: "someone-else"), nil)
        choices.remove(for: "rider")
        expectNoDifference(choices.load(for: "rider"), nil)
    }
}
