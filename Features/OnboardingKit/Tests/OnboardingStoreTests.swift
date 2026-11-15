import CustomDump
import Foundation
import Testing
@testable import OnboardingKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct OnboardingStoreTests {
    @Test
    func `the welcome screen counts as seen on this device once it is marked, across launches`() throws {
        let suiteName = "OnboardingStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let firstLaunch = OnboardingStore.live(defaults: defaults)
        let unseen = firstLaunch.isWelcomeSeen()
        firstLaunch.setWelcomeSeen(true)
        let nextLaunch = OnboardingStore.live(defaults: defaults)

        expectNoDifference(unseen, false)
        expectNoDifference(nextLaunch.isWelcomeSeen(), true)
    }
}
