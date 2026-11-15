import Foundation
import Synchronization

final class TestTime: Sendable {

    // MARK: Computed Properties

    var now: Date {
        current.withLock { $0 }
    }

    // MARK: Properties

    private let current = Mutex(Date(timeIntervalSince1970: 1_000_000))

    // MARK: Functions

    func advance(by seconds: TimeInterval) {
        current.withLock { $0.addTimeInterval(seconds) }
    }
}
