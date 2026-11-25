import Foundation

/// The line Share sends beside the page: the spot, then who took the photo or clip.
enum PhotoViewerShare {

    // MARK: Static Functions

    static func text(spot: String, credit: String?, isClip: Bool) -> String {
        guard let credit, !credit.isEmpty else {
            return spot
        }
        return isClip
            ? SpotDetailKitStrings.PhotoViewer.Share.videoText(spot, credit)
            : SpotDetailKitStrings.PhotoViewer.Share.photoText(spot, credit)
    }
}
