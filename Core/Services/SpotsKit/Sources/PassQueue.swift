/// One pass at a time. A caller that asks during a pass gets the next one, so it sees what changed before it asked;
/// one that joins takes the pass already under way, if any.
public actor PassQueue<Outcome: Sendable> {

    // MARK: Properties

    private var current = [CheckedContinuation<Outcome, Never>]()
    private var next = [CheckedContinuation<Outcome, Never>]()
    private var worker: Task<Void, Never>?

    // MARK: Lifecycle

    public init() { }

    // MARK: Functions

    public func run(joining: Bool = false, _ pass: @escaping @Sendable () async -> Outcome) async -> Outcome {
        await withCheckedContinuation { continuation in
            if joining, worker != nil {
                current.append(continuation)
            } else {
                next.append(continuation)
            }
            if worker == nil {
                worker = Task { await drain(pass) }
            }
        }
    }

    /// Cancels the pass under way and waits for it; callers still waiting get what the cancelled passes return.
    public func cancel() async {
        let running = worker
        running?.cancel()
        await running?.value
    }

    private func drain(_ pass: @Sendable () async -> Outcome) async {
        while !next.isEmpty {
            current = next
            next = []
            let outcome = await pass()
            let answered = current
            current = []
            for continuation in answered {
                continuation.resume(returning: outcome)
            }
        }
        worker = nil
    }
}
