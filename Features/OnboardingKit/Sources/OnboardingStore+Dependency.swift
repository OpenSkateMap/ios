public import FactoryKit
import Foundation

extension Container {
    public var onboardingStore: Factory<OnboardingStore> {
        self { .live(defaults: .standard) }
            .singleton
            .onTest { .inMemory() }
            .onPreview { .inMemory() }
    }
}
