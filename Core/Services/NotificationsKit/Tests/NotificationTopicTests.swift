import CustomDump
import Testing
@testable import NotificationsKit

@Suite(.timeLimit(.minutes(1)))
struct NotificationTopicTests {
    @Test
    func `settings lists every known kind in the app's order and words, then anything the server added`() {
        let topics = NotificationTopic.ordered([
            (slug: "new-spots", name: "New spots", description: nil, isOn: false),
            (slug: "weekly-tips", name: "Weekly tips", description: "Tricks to learn", isOn: true),
            (slug: "review-results", name: "Review results", description: nil, isOn: true),
        ])

        expectNoDifference(topics.map(\.id), [
            "review-results",
            "collection-invites",
            "spot-changes",
            "new-spots",
            "review-queue",
            "weekly-tips",
        ])
        expectNoDifference(topics.map(\.title), [
            NotificationsKitStrings.Topic.ReviewResults.title,
            NotificationsKitStrings.Topic.CollectionInvites.title,
            NotificationsKitStrings.Topic.SpotChanges.title,
            NotificationsKitStrings.Topic.NewSpots.title,
            NotificationsKitStrings.Topic.ReviewQueue.title,
            "Weekly tips",
        ])
        expectNoDifference(topics.map(\.isOn), [true, false, false, false, false, true])
        expectNoDifference(topics.map(\.isAvailable), [true, false, false, true, false, true])
    }
}
