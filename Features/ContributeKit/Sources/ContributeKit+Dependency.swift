public import FactoryKit

extension Container {
    public var contributeTabOpener: Factory<(@MainActor @Sendable () -> Void)?> {
        promised()
    }
}
