public import Observation

@MainActor
@Observable
public final class SpotSelection {

    // MARK: Properties

    public var spotID: String?
    /// The spot's sheet opens Suggest an Edit once the spot's page has loaded, then clears it.
    public var suggestsEdit = false

    // MARK: Lifecycle

    public init(spotID: String? = nil) {
        self.spotID = spotID
    }
}
