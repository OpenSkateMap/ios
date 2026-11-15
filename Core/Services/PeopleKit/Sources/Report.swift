// MARK: - Report

/// Something flagged for the admins (App Store guideline 1.2).
public struct Report: Equatable, Sendable {

    // MARK: Types

    public enum Target: Equatable, Sendable {
        case spot(id: String)
        case user(id: String)
    }

    public enum Reason: String, CaseIterable, Sendable {
        case inappropriate
        case spam
        case wrongInfo = "wrong_info"
        case privateProperty = "private_property"
        case photoRights = "photo_rights"
        case harassment
        case other

        // MARK: Computed Properties

        public var title: String {
            switch self {
            case .inappropriate: PeopleKitStrings.Report.Reason.inappropriate
            case .spam: PeopleKitStrings.Report.Reason.spam
            case .wrongInfo: PeopleKitStrings.Report.Reason.wrongInfo
            case .privateProperty: PeopleKitStrings.Report.Reason.privateProperty
            case .photoRights: PeopleKitStrings.Report.Reason.photoRights
            case .harassment: PeopleKitStrings.Report.Reason.harassment
            case .other: PeopleKitStrings.Report.Reason.other
            }
        }

        // MARK: Static Functions

        public static func offered(for target: Target) -> [Reason] {
            switch target {
            case .spot: [.wrongInfo, .privateProperty, .photoRights, .inappropriate, .spam, .other]
            case .user: [.harassment, .inappropriate, .spam, .photoRights, .other]
            }
        }
    }

    // MARK: Properties

    public var target: Target
    public var reason: Reason
    public var message: String

    // MARK: Lifecycle

    public init(target: Target, reason: Reason, message: String = "") {
        self.target = target
        self.reason = reason
        self.message = message
    }
}
