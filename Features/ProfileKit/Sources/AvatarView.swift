import ComponentKit
import ImageKit
import PeopleKit
import PinLayout
import UIKit

final class AvatarView: UIView {

    // MARK: Properties

    private let imageView = UIImageView()
    private let initialsLabel = Label()
    private let loader = PhotoLoader()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        clipsToBounds = true
        backgroundColor = .tertiarySystemFill
        imageView.contentMode = .scaleAspectFill
        initialsLabel.textAlignment = .center
        initialsLabel.textColor = .secondaryLabel
        addSubview(initialsLabel)
        addSubview(imageView)
        accessibilityElementsHidden = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.width / 2
        imageView.pin
            .all()
        initialsLabel.pin
            .all()
        initialsLabel.font = .systemFont(ofSize: max(bounds.width * 0.36, 12), weight: .semibold)
    }

    // MARK: Static Functions

    private static func initials(of name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
    }

    // MARK: Functions

    func show(name: String, avatar: PublicProfile.Avatar?) {
        initialsLabel.text = Self.initials(of: name)
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 3
        loader.show(key: avatar?.key, thumbhash: avatar?.thumbhash, size: .avatar, scale: scale, in: imageView)
    }

    func show(name: String, image: UIImage?) {
        initialsLabel.text = Self.initials(of: name)
        loader.cancel()
        imageView.image = image
    }
}
