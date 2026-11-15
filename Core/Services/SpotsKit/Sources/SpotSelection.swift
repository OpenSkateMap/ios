public import Observation

@MainActor
@Observable
public final class SpotSelection {

    // MARK: Properties

    public var spotID: String?

    // MARK: Lifecycle

    public init(spotID: String? = nil) {
        self.spotID = spotID
    }
}
