public import SpotModelKit

extension SpotRemovalReason {
    /// What an admin picks.
    public var title: String {
        switch self {
        case .duplicate: ComponentKitStrings.SpotRemoval.Duplicate.title
        case .privateProperty: ComponentKitStrings.SpotRemoval.PrivateProperty.title
        case .unsafeOrGone: ComponentKitStrings.SpotRemoval.UnsafeOrGone.title
        case .notASpot: ComponentKitStrings.SpotRemoval.NotASpot.title
        case .other: ComponentKitStrings.SpotRemoval.Other.title
        }
    }

    /// What the person who added the spot reads.
    public var explanation: String {
        switch self {
        case .duplicate: ComponentKitStrings.SpotRemoval.Duplicate.explanation
        case .privateProperty: ComponentKitStrings.SpotRemoval.PrivateProperty.explanation
        case .unsafeOrGone: ComponentKitStrings.SpotRemoval.UnsafeOrGone.explanation
        case .notASpot: ComponentKitStrings.SpotRemoval.NotASpot.explanation
        case .other: ComponentKitStrings.SpotRemoval.Other.explanation
        }
    }
}
