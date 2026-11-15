import ComponentKit
import PinLayout
import SpotModelKit
import UIKit

final class CollectionPreviewCell: UICollectionViewCell {

    // MARK: Properties

    private let hero = CollectionHeroView()
    private let photoButton = UIButton(configuration: .plain())

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        hero.pin
            .top()
            .horizontally()
            .height(Self.heroHeight(width: bounds.width))
        photoButton.pin
            .below(of: hero)
            .hCenter()
            .marginTop(8)
            .sizeToFit()
    }

    override func preferredLayoutAttributesFitting(_ attributes: UICollectionViewLayoutAttributes)
        -> UICollectionViewLayoutAttributes {
        let fitted = attributes.copy() as? UICollectionViewLayoutAttributes ?? attributes
        fitted.size.height = Self.heroHeight(width: attributes.size.width) + 8 + photoButton.sizeThatFits(attributes.size).height
        return fitted
    }

    // MARK: Static Functions

    private static func heroHeight(width: CGFloat) -> CGFloat {
        (width * 0.75).rounded()
    }

    // MARK: Functions

    func show(name: String, backdrop: CollectionHeroView.Backdrop, photoMenu: UIMenu, isPreparingPhoto: Bool, isEnabled: Bool) {
        hero.content = CollectionHeroView.Content(title: name, subtitle: nil, backdrop: backdrop)
        photoButton.menu = photoMenu
        photoButton.configuration?.showsActivityIndicator = isPreparingPhoto
        photoButton.isEnabled = isEnabled && !isPreparingPhoto
        setNeedsLayout()
    }

    private func setupViews() {
        hero.layer.cornerRadius = 26
        hero.layer.cornerCurve = .continuous
        photoButton.configuration?.title = CollectionDetailKitStrings.Edit.choosePhoto
        photoButton.showsMenuAsPrimaryAction = true
        contentView.addSubview(hero)
        contentView.addSubview(photoButton)
    }
}
