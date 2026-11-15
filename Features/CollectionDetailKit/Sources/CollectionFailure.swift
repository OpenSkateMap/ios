import CollectionsKit
import ComponentKit

enum CollectionFailure {
    /// `notFound` says why for a 404 that means something specific.
    @MainActor
    static func show(_ title: String, _ error: any Error, notFound: String? = nil) {
        let reason = (error as? CollectionsAPIError == .notFound ? notFound : nil) ?? message(for: error)
        ToastView.showFailure(title, subtitle: reason)
    }

    static func message(for error: any Error) -> String {
        switch error as? CollectionsAPIError {
        case .offline: CollectionDetailKitStrings.Alert.offline
        case .unavailable: CollectionDetailKitStrings.Alert.unavailable
        case .unauthorized: CollectionDetailKitStrings.Alert.unauthorized
        case .forbidden: CollectionDetailKitStrings.Alert.forbidden
        case .notFound: CollectionDetailKitStrings.Alert.notFound
        case .refused(let message?): CollectionDetailKitStrings.Alert.refused(message)
        case .refused(.none): CollectionDetailKitStrings.Alert.refusedUnknown
        case nil: CollectionDetailKitStrings.Alert.unknown
        }
    }
}
