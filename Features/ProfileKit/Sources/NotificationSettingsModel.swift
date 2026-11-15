import AccountKit
import FactoryKit
import IdentifiedCollections
import NotificationsKit
import Observation

// MARK: - NotificationSettingsModel

@MainActor
@Observable
final class NotificationSettingsModel {

    // MARK: Properties

    private(set) var permission: NotificationPermission?
    private(set) var topics: IdentifiedArrayOf<NotificationTopic>
    private(set) var loadFailed = false
    private(set) var saveFailed = false

    @ObservationIgnored @Injected(\.notificationsManager) private var notifications
    @ObservationIgnored private let isCurator: Bool
    @ObservationIgnored private var latestChange = [NotificationTopic.ID: Int]()
    @ObservationIgnored private var changeCount = 0
    @ObservationIgnored private var isLoaded = false

    // MARK: Lifecycle

    init() {
        if case .signedIn(let account) = Container.shared.authSession().phase {
            isCurator = account.role != .user
        } else {
            isCurator = false
        }
        topics = []
        if let cached = notifications.cachedTopics() {
            topics = visible(cached)
            isLoaded = true
        } else {
            topics = visible(NotificationTopic.placeholders)
        }
    }

    // MARK: Functions

    func load() async {
        await refreshPermission()
        do {
            topics = visible(try await notifications.topics())
            isLoaded = true
            loadFailed = false
        } catch {
            loadFailed = !isLoaded
        }
    }

    func refreshPermission() async {
        permission = await notifications.permission()
    }

    func turnOn() async {
        permission = await notifications.requestPermission()
    }

    func set(_ id: NotificationTopic.ID, isOn: Bool) async {
        guard let topic = topics[id: id], topic.isAvailable, topic.isOn != isOn else {
            return
        }
        changeCount += 1
        let change = changeCount
        latestChange[id] = change
        topics[id: id]?.isOn = isOn
        do {
            let saved = try await notifications.setTopic(id, isOn)
            guard latestChange[id] == change, let topic = saved.first(where: { $0.id == id }) else {
                return
            }
            topics[id: id] = topic
        } catch {
            guard latestChange[id] == change else {
                return
            }
            topics[id: id]?.isOn = !isOn
            saveFailed = true
        }
    }

    func dismissSaveFailure() {
        saveFailed = false
    }

    private func visible(_ topics: [NotificationTopic]) -> IdentifiedArrayOf<NotificationTopic> {
        IdentifiedArray(topics.filter { !$0.isForCurators || isCurator }) { first, _ in first }
    }
}
