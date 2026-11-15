#if DEBUG
enum LaunchArgument {
    static let previewAuth = "-OSMPreviewAuth"
    static let previewSignedIn = "-OSMPreviewSignedIn"
    static let resetOnboarding = "-OSMResetOnboarding"
    /// Value arguments are read from `UserDefaults` (the launch arguments' domain), so their keys have no dash.
    static let apiBaseURL = "OSMAPIBaseURL"
    static let imagesBaseURL = "OSMImagesBaseURL"
    static let debugToken = "OSMDebugToken"
}
#endif
