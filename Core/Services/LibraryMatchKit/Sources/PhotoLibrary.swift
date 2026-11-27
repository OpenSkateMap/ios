public import Foundation
public import UIKit

// MARK: - PhotoLibrary

/// The person's photo library, read on this device only.
public struct PhotoLibrary: Sendable {
    /// Reading it never asks.
    public var access: @Sendable () -> PhotoAccess
    /// Shows the system's prompt when it hasn't been answered.
    public var requestAccess: @Sendable () async -> PhotoAccess
    /// Photos with a location: all of them without a token (or when it expired), else those added or changed since.
    public var changes: @Sendable (_ since: Data?) async -> LibraryChanges
    /// The asset's image about `side` pixels on its shorter edge; `allowsNetwork` lets an iCloud-only one download.
    public var image: @Sendable (_ assetID: String, _ side: CGFloat, _ allowsNetwork: Bool) async -> UIImage?
    /// The asset's original bytes, for the photo intake to prepare like a picked file.
    public var imageData: @Sendable (_ assetID: String) async -> Data?

    public init(access: @escaping @Sendable () -> PhotoAccess,
                requestAccess: @escaping @Sendable () async -> PhotoAccess,
                changes: @escaping @Sendable (_ since: Data?) async -> LibraryChanges,
                image: @escaping @Sendable (_ assetID: String, _ side: CGFloat, _ allowsNetwork: Bool) async -> UIImage?,
                imageData: @escaping @Sendable (_ assetID: String) async -> Data?) {
        self.access = access
        self.requestAccess = requestAccess
        self.changes = changes
        self.image = image
        self.imageData = imageData
    }
}

extension PhotoLibrary {
    public static let preview = PhotoLibrary {
        .notDetermined
    } requestAccess: {
        .denied
    } changes: { _ in
        LibraryChanges(isComplete: true, assets: [], deletedIDs: [], token: nil)
    } image: { _, _, _ in
        nil
    } imageData: { _ in
        nil
    }
}

// MARK: - PhotoAccess

public enum PhotoAccess: Equatable, Sendable {
    case notDetermined
    /// Denied, or restricted by the device's owner.
    case denied
    /// Only the photos the person chose to share.
    case limited
    case full
}

// MARK: - LibraryAsset

public struct LibraryAsset: Equatable, Sendable {
    public var id: String
    public var latitude: Double
    public var longitude: Double
    public var takenAt: Date

    public init(id: String, latitude: Double, longitude: Double, takenAt: Date) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.takenAt = takenAt
    }
}

// MARK: - LibraryChanges

public struct LibraryChanges: Equatable, Sendable {
    /// Every photo with a location rather than what changed: matches it doesn't find again are gone.
    public var isComplete: Bool
    public var assets: [LibraryAsset]
    public var deletedIDs: Set<String>
    /// Taken before reading, so what changes meanwhile shows up next time.
    public var token: Data?

    public init(isComplete: Bool, assets: [LibraryAsset], deletedIDs: Set<String>, token: Data?) {
        self.isComplete = isComplete
        self.assets = assets
        self.deletedIDs = deletedIDs
        self.token = token
    }
}
