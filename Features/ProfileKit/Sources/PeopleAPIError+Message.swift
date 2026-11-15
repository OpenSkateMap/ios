import PeopleKit

extension PeopleAPIError {
    var message: String {
        switch self {
        case .unauthorized: ProfileKitStrings.PeopleError.unauthorized
        case .offline: ProfileKitStrings.PeopleError.offline
        case .unavailable: ProfileKitStrings.PeopleError.unavailable
        case .notFound: ProfileKitStrings.PeopleError.notFound
        case .usernameUnavailable: ProfileKitStrings.PeopleError.usernameUnavailable
        case .rejected(let message): message
        }
    }

    static func message(for error: any Error) -> String {
        (error as? PeopleAPIError)?.message ?? PeopleAPIError.unavailable.message
    }
}
