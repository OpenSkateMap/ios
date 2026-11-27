public import Observation

@MainActor
@Observable
public final class SpotSelection {

    // MARK: Nested Types

    /// Suggest an Edit, asked for with the spot.
    public struct EditRequest: Equatable, Sendable {
        /// Photos from the person's library the edit starts with, by PhotoKit local identifier.
        public var libraryPhotoIDs: [String]

        public init(libraryPhotoIDs: [String] = []) {
            self.libraryPhotoIDs = libraryPhotoIDs
        }
    }

    // MARK: Properties

    public var spotID: String?
    /// The spot's sheet opens Suggest an Edit once the spot's page has loaded, then clears it.
    public var editRequest: EditRequest?

    // MARK: Lifecycle

    public init(spotID: String? = nil) {
        self.spotID = spotID
    }
}
