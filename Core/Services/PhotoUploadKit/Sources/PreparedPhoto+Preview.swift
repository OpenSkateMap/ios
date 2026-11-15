public import UIKit

extension PreparedPhoto {
    /// The photo decoded off the main thread at no more than `maxPixelSide` on its longer side, for showing it in a
    /// view; the JPEG itself is up to 2048 px, and decoded as is it would stay in memory at full size.
    @concurrent
    public func preview(maxPixelSide: CGFloat) async -> UIImage? {
        guard let image = UIImage(data: jpeg) else {
            return nil
        }
        let scale = min(1, maxPixelSide / max(image.size.width, image.size.height, 1))
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        return await image.byPreparingThumbnail(ofSize: size)
    }
}
