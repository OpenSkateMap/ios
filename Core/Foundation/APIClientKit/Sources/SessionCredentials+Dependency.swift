public import FactoryKit
public import Foundation

extension Container {
    public var sessionCredentials: Factory<SessionCredentials> {
        self { .signedOut }.singleton
    }

    public var apiServerURL: Factory<URL> {
        self { .openSkateMapAPI }.singleton
    }
}
