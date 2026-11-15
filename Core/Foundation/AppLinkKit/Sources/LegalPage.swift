public import Foundation

public enum LegalPage: CaseIterable, Sendable {
    case privacy
    case terms

    // MARK: Computed Properties

    public var title: String {
        switch self {
        case .privacy: AppLinkKitStrings.LegalPage.privacy
        case .terms: AppLinkKitStrings.LegalPage.terms
        }
    }

    public var url: URL {
        switch self {
        case .privacy: URL(string: "https://\(AppLink.host)/privacy")!
        case .terms: URL(string: "https://\(AppLink.host)/terms")!
        }
    }
}
