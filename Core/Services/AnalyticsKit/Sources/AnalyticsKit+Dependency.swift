public import FactoryKit

extension Container {
    public var analyticsManager: Factory<AnalyticsManager> {
        self { .live }.singleton.onPreview { .preview }.onTest { .preview }
    }
}
