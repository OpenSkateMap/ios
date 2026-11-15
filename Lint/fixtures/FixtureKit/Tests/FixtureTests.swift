// Lint fixture, never compiled: `mise run ios:lint` checks that each rule still flags the line after
// an `// expect:` comment and nothing else. See FixtureCell.swift for the convention.

func taskSleepIsFlaggedOutsideComments() async throws {
    // Task.sleep(for: .seconds(1)) in a comment
    // expect: task_sleep_in_tests
    try await Task.sleep(for: .seconds(1))
}

func clockSleepIsFlagged(clock: ContinuousClock) async throws {
    // expect: task_sleep_in_tests
    try await clock.sleep(for: .seconds(1))
}

func taskYieldIsFlagged() async {
    // expect: task_sleep_in_tests
    await Task.yield()
}

func specializedTaskSleepIsFlagged() async throws {
    // expect: task_sleep_in_tests
    try await Task<Never, Never>.sleep(nanoseconds: 1)
}
