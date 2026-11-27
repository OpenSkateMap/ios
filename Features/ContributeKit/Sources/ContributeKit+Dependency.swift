public import FactoryKit

extension Container {
    public var contributeTabOpener: Factory<(@MainActor @Sendable () -> Void)?> {
        promised()
    }

    /// Opens a spot on the map with its Suggest an Edit over it (Edit Spot for an admin), by the spot's id.
    public var spotEditOpener: Factory<(@MainActor @Sendable (String) -> Void)?> {
        promised()
    }
}
