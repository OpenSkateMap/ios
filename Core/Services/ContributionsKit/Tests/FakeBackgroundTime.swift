@testable import ContributionsKit

actor FakeBackgroundTime {

    // MARK: Types

    enum Event: Equatable {
        case began
        case beganShown(String)
        case progress(completed: Int, total: Int, subtitle: String)
        case ended
    }

    // MARK: Computed Properties

    nonisolated var backgroundTime: BackgroundTime {
        BackgroundTime { work, expired in
            await self.begin(.began, expired)
            await work()
            self.reports.continuation.yield(.ended)
        } runShown: { title, work, expired in
            await self.begin(.beganShown(title), expired)
            let reports = self.reports
            await work(BackgroundProgress { completed, total, subtitle in
                reports.continuation.yield(.progress(completed: completed, total: total, subtitle: subtitle))
            })
            self.reports.continuation.yield(.ended)
        }
    }

    nonisolated var events: AsyncStream<Event> {
        reports.stream
    }

    // MARK: Properties

    private let reports = AsyncStream<Event>.makeStream()
    private var expired: (@Sendable () async -> Void)?

    // MARK: Functions

    func expire() async {
        await expired?()
    }

    private func begin(_ event: Event, _ expired: @escaping @Sendable () async -> Void) {
        self.expired = expired
        reports.continuation.yield(event)
    }
}
