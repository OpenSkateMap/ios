public import FactoryKit

extension Container {
    public var accountEndHandler: Factory<AccountEndHandler> {
        self { .none }.singleton
    }
}
