import PinLayout
import UIKit

final class AvatarEditorView: UIView {

    // MARK: Properties

    let avatar = AvatarView()
    let button = UIButton(configuration: .plain())

    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        var configuration = UIButton.Configuration.plain()
        configuration.title = ProfileKitStrings.EditProfile.Photo.change
        button.configuration = configuration
        button.showsMenuAsPrimaryAction = true
        spinner.hidesWhenStopped = true
        addSubview(avatar)
        addSubview(spinner)
        addSubview(button)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        avatar.pin
            .top()
            .hCenter()
            .size(96)
        spinner.pin
            .center(to: avatar.anchor.center)
        button.pin
            .below(of: avatar)
            .hCenter()
            .marginTop(8)
            .sizeToFit()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: 96 + 8 + button.sizeThatFits(size).height)
    }

    // MARK: Functions

    func setPreparing(_ preparing: Bool) {
        if preparing {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
        button.isEnabled = !preparing
    }
}
