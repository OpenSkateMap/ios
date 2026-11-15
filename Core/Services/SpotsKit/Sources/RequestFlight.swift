/// A burst of changes to one spot: only the newest settles, on the last value the server confirmed.
struct RequestFlight<Value: Sendable> {

    // MARK: Computed Properties

    var isIdle: Bool {
        waiting.isEmpty
    }

    // MARK: Properties

    private(set) var newest = 0

    private var waiting = Set<Int>()
    private var confirmed: (ticket: Int, value: Value)?

    // MARK: Functions

    mutating func start(_ ticket: Int) {
        waiting.insert(ticket)
        newest = max(newest, ticket)
    }

    mutating func stored(_ value: Value) {
        if confirmed == nil {
            confirmed = (0, value)
        }
    }

    mutating func succeeded(_ ticket: Int, with value: Value) -> Value? {
        waiting.remove(ticket)
        if ticket > (confirmed?.ticket ?? -1) {
            confirmed = (ticket, value)
        }
        return settled(after: ticket)
    }

    mutating func failed(_ ticket: Int) -> Value? {
        waiting.remove(ticket)
        return settled(after: ticket)
    }

    private func settled(after ticket: Int) -> Value? {
        waiting.contains { $0 > ticket } ? nil : confirmed?.value
    }
}
