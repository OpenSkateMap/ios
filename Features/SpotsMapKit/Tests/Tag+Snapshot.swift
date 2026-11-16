import Testing

extension Tag {
    /// CI's required gate skips these (`-skip-testing-tags snapshot`); its Snapshots job runs them.
    @Tag static var snapshot: Self
}
