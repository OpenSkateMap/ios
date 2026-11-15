import FactoryKit

extension Container {
    @MainActor
    var appLinks: Factory<AppLinks> {
        self { AppLinks() }.singleton
    }
}
