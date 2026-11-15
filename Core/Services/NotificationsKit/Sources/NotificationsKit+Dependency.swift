public import FactoryKit
import Synchronization

extension Container {
    public var notificationsManager: Factory<NotificationsManager> {
        self { .live }.singleton.onPreview { .preview }.onTest { .preview }
    }
}

extension NotificationsManager {
    public static var preview: NotificationsManager {
        let topics = Mutex(NotificationTopic.ordered(NotificationTopic.catalog.map { (
            slug: $0.id,
            name: $0.title,
            description: $0.detail,
            isOn: true,
        ) }))
        return NotificationsManager(
            configure: { },
            onOpen: { _ in },
            identify: { _ in },
            setCity: { _ in },
            signOut: { },
            permission: { .allowed },
            requestPermission: { .allowed },
            cachedTopics: { nil },
            topics: { topics.withLock { $0 } },
            setTopic: { id, isOn in
                topics.withLock { topics in
                    for index in topics.indices where topics[index].id == id {
                        topics[index].isOn = isOn
                    }
                    return topics
                }
            },
        )
    }
}
