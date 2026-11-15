enum MapNotice: Equatable {
    case locationDenied
    case locationUnavailable
    case spotNotFound
    case spotUnavailable

    // MARK: Computed Properties

    var title: String {
        switch self {
        case .locationDenied, .locationUnavailable: SpotsMapKitStrings.Map.Notice.Location.title
        case .spotNotFound: SpotsMapKitStrings.Map.Notice.SpotNotFound.title
        case .spotUnavailable: SpotsMapKitStrings.Map.Notice.SpotUnavailable.title
        }
    }

    var message: String {
        switch self {
        case .locationDenied: SpotsMapKitStrings.Map.Notice.LocationDenied.message
        case .locationUnavailable: SpotsMapKitStrings.Map.Notice.LocationUnavailable.message
        case .spotNotFound: SpotsMapKitStrings.Map.Notice.SpotNotFound.message
        case .spotUnavailable: SpotsMapKitStrings.Map.Notice.SpotUnavailable.message
        }
    }

    var offersSettings: Bool {
        self == .locationDenied
    }
}
