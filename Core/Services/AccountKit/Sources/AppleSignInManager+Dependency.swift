public import FactoryKit

extension Container {
    public var appleSignInManager: Factory<AppleSignInManager> {
        self { .live }
            .singleton
            .onPreview { .preview }
    }
}
