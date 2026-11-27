import CoreLocation
import Foundation
import os
import Photos
import UIKit

extension PhotoLibrary {
    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "library-match")

    /// PhotoKit only. Nothing read here leaves the device; the caller decides what's ever sent.
    public static let live = PhotoLibrary {
        PhotoAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    } requestAccess: {
        await PhotoAccess(PHPhotoLibrary.requestAuthorization(for: .readWrite))
    } changes: { @concurrent token in
        let library = PHPhotoLibrary.shared()
        let current = archive(library.currentChangeToken)
        if let token, let changes = changes(in: library, since: token, newToken: current) {
            return changes
        }
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions())
        return LibraryChanges(isComplete: true, assets: located(assets), deletedIDs: [], token: current)
    } image: { @concurrent assetID, side, allowsNetwork in
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
            return nil
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = allowsNetwork
        let scale = side / CGFloat(max(1, min(asset.pixelWidth, asset.pixelHeight)))
        let target = CGSize(width: CGFloat(asset.pixelWidth) * scale, height: CGFloat(asset.pixelHeight) * scale)
        // With `.highQualityFormat` the handler runs once.
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(for: asset, targetSize: target, contentMode: .aspectFill, options: options) {
                image, _ in
                continuation.resume(returning: image)
            }
        }
    } imageData: { @concurrent assetID in
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetID], options: nil).firstObject else {
            return nil
        }
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.version = .current
        options.isNetworkAccessAllowed = true
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }

    private static func changes(in library: PHPhotoLibrary, since archived: Data, newToken: Data?) -> LibraryChanges? {
        guard let token = unarchive(archived) else {
            return nil
        }
        do {
            var changed = Set<String>()
            var deleted = Set<String>()
            for change in try library.fetchPersistentChanges(since: token) {
                let details = try change.changeDetails(for: .asset)
                changed.formUnion(details.insertedLocalIdentifiers)
                changed.formUnion(details.updatedLocalIdentifiers)
                deleted.formUnion(details.deletedLocalIdentifiers)
            }
            changed.subtract(deleted)
            let assets = changed.isEmpty
                ? []
                : located(PHAsset.fetchAssets(withLocalIdentifiers: Array(changed), options: fetchOptions(imagesOnly: true)))
            return LibraryChanges(isComplete: false, assets: assets, deletedIDs: deleted, token: newToken)
        } catch {
            // An expired token or missing history: the caller reads the whole library instead.
            logger.notice("Library changes unavailable, reading every photo: \(String(describing: error), privacy: .public)")
            return nil
        }
    }

    /// The person's own library: not shared albums, which hold other people's photos.
    private static func fetchOptions(imagesOnly: Bool = false) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.includeAssetSourceTypes = [.typeUserLibrary]
        if imagesOnly {
            options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        }
        return options
    }

    private static func located(_ assets: PHFetchResult<PHAsset>) -> [LibraryAsset] {
        var located = [LibraryAsset]()
        assets.enumerateObjects { asset, _, _ in
            guard !asset.mediaSubtypes.contains(.photoScreenshot), let location = asset.location else {
                return
            }
            located.append(LibraryAsset(
                id: asset.localIdentifier,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                takenAt: asset.creationDate ?? location.timestamp,
            ))
        }
        return located
    }

    private static func archive(_ token: PHPersistentChangeToken) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
    }

    private static func unarchive(_ data: Data) -> PHPersistentChangeToken? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: PHPersistentChangeToken.self, from: data)
    }
}

// MARK: - PhotoAccess + PHAuthorizationStatus

extension PhotoAccess {
    init(_ status: PHAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notDetermined
        case .limited: self = .limited
        case .authorized: self = .full
        case .denied, .restricted: self = .denied
        @unknown default: self = .denied
        }
    }
}
