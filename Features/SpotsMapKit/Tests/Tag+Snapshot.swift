import Testing

extension Tag {
    /// CI's required gate skips these (`-skip-testing-tags snapshot`); the Snapshots workflow runs them.
    @Tag static var snapshot: Self
}
