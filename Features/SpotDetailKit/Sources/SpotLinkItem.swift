import LinkPresentation
import UIKit

final class SpotLinkItem: NSObject, UIActivityItemSource {

    // MARK: Properties

    private let url: URL
    private let title: String
    private let image: UIImage?

    // MARK: Lifecycle

    init(url: URL, title: String, image: UIImage?) {
        self.url = url
        self.title = title
        self.image = image
    }

    // MARK: Functions

    func activityViewControllerPlaceholderItem(_: UIActivityViewController) -> Any {
        url
    }

    func activityViewController(_: UIActivityViewController, itemForActivityType _: UIActivity.ActivityType?) -> Any? {
        url
    }

    func activityViewControllerLinkMetadata(_: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.originalURL = url
        metadata.url = url
        metadata.title = title
        if let image {
            metadata.imageProvider = NSItemProvider(object: image)
        }
        return metadata
    }
}
