public import Foundation
import Synchronization

// MARK: - OnboardingStore

nonisolated public struct OnboardingStore: Sendable {
    public var isWelcomeSeen: @Sendable () -> Bool
    public var setWelcomeSeen: @Sendable (Bool) -> Void

    public init(isWelcomeSeen: @escaping @Sendable () -> Bool, setWelcomeSeen: @escaping @Sendable (Bool) -> Void) {
        self.isWelcomeSeen = isWelcomeSeen
        self.setWelcomeSeen = setWelcomeSeen
    }
}

nonisolated extension OnboardingStore {
    static let welcomeSeenKey = "onboarding.welcome.seen.v3"

    public static func live(defaults: UserDefaults) -> OnboardingStore {
        // UserDefaults is documented as thread-safe but not marked Sendable.
        nonisolated(unsafe) let defaults = defaults
        return OnboardingStore(
            isWelcomeSeen: { defaults.bool(forKey: welcomeSeenKey) },
            setWelcomeSeen: { defaults.set($0, forKey: welcomeSeenKey) },
        )
    }

    public static func inMemory(seen: Bool = false) -> OnboardingStore {
        let seen = Mutex(seen)
        return OnboardingStore(
            isWelcomeSeen: { seen.withLock { $0 } },
            setWelcomeSeen: { value in seen.withLock { $0 = value } },
        )
    }
}
