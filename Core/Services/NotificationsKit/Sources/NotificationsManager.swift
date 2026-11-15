public import Foundation

// MARK: - NotificationPermission

public enum NotificationPermission: Equatable, Sendable {
    case notAsked
    case allowed
    case denied
}

// MARK: - NotificationDestination

public enum NotificationDestination: Equatable, Sendable {
    case link(URL)
    case contribute
    case reviewQueue
}

// MARK: - NotificationSubscriber

/// The identity hash is the server's signature of the id, so the app's public key can't speak for anyone else.
public struct NotificationSubscriber: Equatable, Sendable {
    public var id: String
    public var name: String
    public var role: String
    public var joinedAt: Date
    public var identityHash: String

    public init(id: String, name: String, role: String, joinedAt: Date, identityHash: String) {
        self.id = id
        self.name = name
        self.role = role
        self.joinedAt = joinedAt
        self.identityHash = identityHash
    }
}

// MARK: - NotificationTopic

public struct NotificationTopic: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var isForCurators: Bool
    public var isOn: Bool
    public var isAvailable: Bool

    public init(id: String, title: String, detail: String, isForCurators: Bool, isOn: Bool, isAvailable: Bool) {
        self.id = id
        self.title = title
        self.detail = detail
        self.isForCurators = isForCurators
        self.isOn = isOn
        self.isAvailable = isAvailable
    }
}

// MARK: - NotificationsManager

public struct NotificationsManager: Sendable {
    public var configure: @Sendable () -> Void
    public var onOpen: @Sendable (_ handler: @escaping @MainActor @Sendable (NotificationDestination) -> Void) -> Void
    public var identify: @Sendable (_ subscriber: NotificationSubscriber) -> Void
    public var setCity: @Sendable (_ cityId: String) -> Void
    public var signOut: @Sendable () -> Void
    public var permission: @Sendable () async -> NotificationPermission
    public var requestPermission: @Sendable () async -> NotificationPermission
    /// The identified subscriber's last loaded choices; nil before the first load or after sign-out.
    public var cachedTopics: @Sendable () -> [NotificationTopic]?
    public var topics: @Sendable () async throws -> [NotificationTopic]
    public var setTopic: @Sendable (_ id: NotificationTopic.ID, _ isOn: Bool) async throws -> [NotificationTopic]

    public init(configure: @escaping @Sendable () -> Void,
                onOpen: @escaping @Sendable (_ handler: @escaping @MainActor @Sendable (NotificationDestination) -> Void) -> Void,
                identify: @escaping @Sendable (_ subscriber: NotificationSubscriber) -> Void,
                setCity: @escaping @Sendable (_ cityId: String) -> Void,
                signOut: @escaping @Sendable () -> Void,
                permission: @escaping @Sendable () async -> NotificationPermission,
                requestPermission: @escaping @Sendable () async -> NotificationPermission,
                cachedTopics: @escaping @Sendable () -> [NotificationTopic]?,
                topics: @escaping @Sendable () async throws -> [NotificationTopic],
                setTopic: @escaping @Sendable (_ id: NotificationTopic.ID, _ isOn: Bool) async throws -> [NotificationTopic]) {
        self.configure = configure
        self.onOpen = onOpen
        self.identify = identify
        self.setCity = setCity
        self.signOut = signOut
        self.permission = permission
        self.requestPermission = requestPermission
        self.cachedTopics = cachedTopics
        self.topics = topics
        self.setTopic = setTopic
    }
}

// MARK: - Catalog

extension NotificationTopic {
    static let catalog: [(id: String, title: String, detail: String, isForCurators: Bool)] = [
        (
            "review-results",
            NotificationsKitStrings.Topic.ReviewResults.title,
            NotificationsKitStrings.Topic.ReviewResults.detail,
            false,
        ),
        (
            "collection-invites",
            NotificationsKitStrings.Topic.CollectionInvites.title,
            NotificationsKitStrings.Topic.CollectionInvites.detail,
            false,
        ),
        (
            "spot-changes",
            NotificationsKitStrings.Topic.SpotChanges.title,
            NotificationsKitStrings.Topic.SpotChanges.detail,
            false,
        ),
        ("new-spots", NotificationsKitStrings.Topic.NewSpots.title, NotificationsKitStrings.Topic.NewSpots.detail, false),
        ("review-queue", NotificationsKitStrings.Topic.ReviewQueue.title, NotificationsKitStrings.Topic.ReviewQueue.detail, true),
    ]

    public static var placeholders: [NotificationTopic] {
        ordered([])
    }

    static func ordered(_ topics: [(slug: String, name: String, description: String?, isOn: Bool)]) -> [NotificationTopic] {
        let known = catalog.map { entry in
            let topic = topics.first { $0.slug == entry.id }
            return NotificationTopic(
                id: entry.id,
                title: entry.title,
                detail: entry.detail,
                isForCurators: entry.isForCurators,
                isOn: topic?.isOn ?? false,
                isAvailable: topic != nil,
            )
        }
        let added = topics.filter { topic in !catalog.contains { $0.id == topic.slug } }.map { topic in
            NotificationTopic(
                id: topic.slug,
                title: topic.name,
                detail: topic.description ?? "",
                isForCurators: false,
                isOn: topic.isOn,
                isAvailable: true,
            )
        }
        return known + added
    }
}
