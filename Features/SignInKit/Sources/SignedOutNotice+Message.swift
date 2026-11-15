import AccountKit

extension SignedOutNotice {
    var message: String {
        switch self {
        case .appleSignInFailed: SignInKitStrings.SignIn.Notice.appleSignInFailed
        case .offline: SignInKitStrings.SignIn.Notice.offline
        case .signInRejected: SignInKitStrings.SignIn.Notice.signInRejected
        case .serverUnavailable: SignInKitStrings.SignIn.Notice.serverUnavailable
        case .sessionExpired: SignInKitStrings.SignIn.Notice.sessionExpired
        case .accountDisabled: SignInKitStrings.SignIn.Notice.accountDisabled
        case .accountDeleted: SignInKitStrings.SignIn.Notice.accountDeleted
        }
    }

    var isFailure: Bool {
        switch self {
        case .appleSignInFailed, .offline, .signInRejected, .serverUnavailable, .accountDisabled: true
        case .sessionExpired, .accountDeleted: false
        }
    }
}
