import CustomDump
import Foundation
import Testing
@testable import ProfileKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AccountAgeTests {

    // MARK: Static Properties

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    private static let joined = date(2026, 10, 10, hour: 0)

    // MARK: Static Functions

    private static func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private static func age(at now: Date) -> AccountAge {
        AccountAge(joinedAt: joined, now: now, calendar: calendar)
    }

    // MARK: Functions

    @Test
    func `the largest whole unit wins: days under a month, months under a year, then years`() {
        expectNoDifference(
            [
                Self.age(at: Self.date(2026, 10, 10)),
                Self.age(at: Self.date(2026, 10, 22)),
                Self.age(at: Self.date(2026, 11, 9)),
                Self.age(at: Self.date(2026, 11, 10)),
                Self.age(at: Self.date(2027, 10, 9)),
                Self.age(at: Self.date(2027, 10, 10)),
                Self.age(at: Self.date(2029, 10, 9)),
            ],
            [
                AccountAge(count: 1, unit: .days),
                AccountAge(count: 12, unit: .days),
                AccountAge(count: 30, unit: .days),
                AccountAge(count: 1, unit: .months),
                AccountAge(count: 11, unit: .months),
                AccountAge(count: 1, unit: .years),
                AccountAge(count: 2, unit: .years),
            ],
        )
    }

    @Test
    func `a join date ahead of the device's clock reads as one day`() {
        expectNoDifference(Self.age(at: Self.date(2026, 10, 9)), AccountAge(count: 1, unit: .days))
    }

    @Test
    func `captions and VoiceOver follow the count's plural`() {
        let ages = [AccountAge(count: 1, unit: .days), AccountAge(count: 3, unit: .months), AccountAge(count: 2, unit: .years)]
        expectNoDifference(ages.map(\.caption), ["Day", "Months", "Years"])
        expectNoDifference(
            ages.map(\.spoken),
            ["1 day on OpenSkateMap", "3 months on OpenSkateMap", "2 years on OpenSkateMap"],
        )
    }
}
