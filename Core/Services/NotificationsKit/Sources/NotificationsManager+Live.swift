import BuzzKit
import Foundation
import Synchronization
import UserNotifications

extension NotificationsManager {
    /// Public by design: it only reaches BuzzKit's `/v1/client/*`; sending needs the server's key.
    private static let clientKey = "bk_pk_IFc9jktzpDjNv6ER4mB0wm3zVgDxzPT2Zd8jeenK"
    private static let apiURL = URL(string: "https://push-api.openskatemap.app")!

    /// Session tracking is off: the privacy policy promises no analytics.
    public static let live: NotificationsManager = {
        let router = TapRouter()
        let subscriberID = Mutex<String?>(nil)
        let choices = TopicChoices()
        /// Kept only for the subscriber who asked, so an answer that lands after a sign-out or a switch isn't cached.
        @Sendable
        func remember(_ topics: [NotificationTopic], askedBy asker: String?) -> [NotificationTopic] {
            if let asker, subscriberID.withLock({ $0 }) == asker {
                choices.save(topics, for: asker)
            }
            return topics
        }
        return NotificationsManager(
            configure: {
                guard !BuzzKit.isConfigured else {
                    return
                }
                BuzzKit.configure(with: BuzzKit.Configuration(apiKey: clientKey, apiURL: apiURL, automaticSessionTracking: false))
                BuzzKit.onDeepLink { url in router.open(.link(url)) }
                BuzzKit.actions.register("open_contribute") { _ in router.open(.contribute) }
                BuzzKit.actions.register("open_review_queue") { _ in router.open(.reviewQueue) }
            },
            onOpen: { handler in router.setHandler(handler) },
            identify: { subscriber in
                subscriberID.withLock { $0 = subscriber.id }
                BuzzKit.identify(
                    subscriber.id,
                    identityHash: subscriber.identityHash,
                    attributes: [
                        "name": .string(subscriber.name),
                        "role": .string(subscriber.role),
                        "joinedAt": .string(subscriber.joinedAt.formatted(.iso8601)),
                    ],
                )
            },
            setCity: { cityId in BuzzKit.setAttributes(["cityId": .string(cityId)]) },
            signOut: {
                let previous = subscriberID.withLock { id in
                    let previous = id
                    id = nil
                    return previous
                }
                if let previous {
                    choices.remove(for: previous)
                }
                BuzzKit.logout()
            },
            permission: { NotificationPermission(await BuzzKit.notificationPermission()) },
            requestPermission: {
                // Registers the device even when the answer is no, so turning notifications on in Settings later works.
                _ = try? await BuzzKit.registerForPush()
                return NotificationPermission(await BuzzKit.notificationPermission())
            },
            cachedTopics: { subscriberID.withLock { $0 }.flatMap(choices.load(for:)) },
            topics: {
                let asker = subscriberID.withLock { $0 }
                return try remember(NotificationTopic.ordered(await BuzzKit.preferences.all().map(\.row)), askedBy: asker)
            },
            setTopic: { id, isOn in
                let asker = subscriberID.withLock { $0 }
                return try remember(
                    NotificationTopic.ordered(await BuzzKit.preferences.set(id, enabled: isOn).map(\.row)),
                    askedBy: asker,
                )
            },
        )
    }()
}

// MARK: - TapRouter

private final class TapRouter: Sendable {

    // MARK: Types

    private struct State {
        var handler: (@MainActor @Sendable (NotificationDestination) -> Void)?
        var pending: NotificationDestination?
    }

    // MARK: Properties

    private let state = Mutex(State())

    // MARK: Functions

    func open(_ destination: NotificationDestination) {
        let handler = state.withLock { state in
            if state.handler == nil {
                state.pending = destination
            }
            return state.handler
        }
        if let handler {
            Task { @MainActor in handler(destination) }
        }
    }

    func setHandler(_ handler: @escaping @MainActor @Sendable (NotificationDestination) -> Void) {
        let pending = state.withLock { state in
            state.handler = handler
            defer { state.pending = nil }
            return state.pending
        }
        if let pending {
            Task { @MainActor in handler(pending) }
        }
    }
}

extension NotificationPermission {
    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notAsked
        case .denied: self = .denied
        default: self = .allowed
        }
    }
}

extension BuzzKit.Topic {
    fileprivate var row: (slug: String, name: String, description: String?, isOn: Bool) {
        (slug, name, description, isOptedIn)
    }
}
