import ComponentKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

final class VideoThumbnailView: UIView {

    // MARK: Static Properties

    static let size = CGSize(width: 128, height: 72)

    // MARK: Properties

    private let imageView = UIImageView()
    private let glyph = UIImageView()
    private var loading: Task<Void, Never>?

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        layer.cornerRadius = 10
        layer.cornerCurve = .continuous
        clipsToBounds = true
        backgroundColor = .tertiarySystemFill
        imageView.contentMode = .scaleAspectFill
        glyph.tintColor = .secondaryLabel
        glyph.contentMode = .center
        addSubview(imageView)
        addSubview(glyph)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        loading?.cancel()
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        imageView.pin
            .all()
        glyph.pin
            .all()
    }

    // MARK: Functions

    func show(_ provider: VideoProvider, thumbnail: URL?, loader: ImageLoader) {
        glyph.image = UIImage(systemName: provider.symbolName)
        glyph.isHidden = false
        imageView.image = nil
        loading?.cancel()
        guard let thumbnail else {
            return
        }
        loading = Task { [weak self] in
            guard let image = try? await loader.image(thumbnail, Self.size), !Task.isCancelled else {
                return
            }
            self?.imageView.image = image
            self?.glyph.isHidden = true
        }
    }
}
