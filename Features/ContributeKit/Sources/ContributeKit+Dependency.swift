public import FactoryKit

extension Container {
    public var contributeTabOpener: Factory<(@MainActor @Sendable () -> Void)?> {
        promised()
    }

    /// Opens a spot on the map with its Suggest an Edit over it (Edit Spot for an admin), by the spot's id.
    public var spotEditOpener: Factory<SpotEditOpener?> {
        promised()
    }
}

// MARK: - SpotEditOpener

public struct SpotEditOpener: Sendable {
    public var open: @MainActor @Sendable (_ spotID: String, _ libraryPhotoIDs: [String]) -> Void

    public init(open: @escaping @MainActor @Sendable (_ spotID: String, _ libraryPhotoIDs: [String]) -> Void) {
        self.open = open
    }

    /// `libraryPhotoIDs`: photos from the person's library the edit starts with, by PhotoKit local identifier.
    @MainActor
    public func callAsFunction(_ spotID: String, libraryPhotoIDs: [String] = []) {
        open(spotID, libraryPhotoIDs)
    }
}
