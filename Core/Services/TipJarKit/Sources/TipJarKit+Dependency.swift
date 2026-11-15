public import FactoryKit

extension Container {
    public var tipJarManager: Factory<TipJarManager> {
        self { .live }.singleton.onPreview { .preview }.onTest { .preview }
    }
}
