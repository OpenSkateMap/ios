import Foundation

/// How long someone has been on OpenSkateMap, in its largest whole unit: years, else months, else days (at least one).
struct AccountAge: Equatable {

    // MARK: Types

    enum Unit: Equatable {
        case days
        case months
        case years
    }

    private typealias Strings = ProfileKitStrings.Profile.Stats

    // MARK: Computed Properties

    var caption: String {
        switch unit {
        case .days: Strings.Age.days(count)
        case .months: Strings.Age.months(count)
        case .years: Strings.Age.years(count)
        }
    }

    var spoken: String {
        switch unit {
        case .days: Strings.A11y.Age.days(count)
        case .months: Strings.A11y.Age.months(count)
        case .years: Strings.A11y.Age.years(count)
        }
    }

    // MARK: Properties

    var count: Int
    var unit: Unit

    // MARK: Lifecycle

    init(count: Int, unit: Unit) {
        self.count = count
        self.unit = unit
    }

    init(joinedAt: Date, now: Date, calendar: Calendar = .current) {
        let elapsed = calendar.dateComponents([.year, .month, .day], from: joinedAt, to: now)
        if let years = elapsed.year, years > 0 {
            self.init(count: years, unit: .years)
        } else if let months = elapsed.month, months > 0 {
            self.init(count: months, unit: .months)
        } else {
            self.init(count: max(1, elapsed.day ?? 0), unit: .days)
        }
    }
}
