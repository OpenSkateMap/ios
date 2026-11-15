import PinLayout
public import UIKit

// MARK: - ActionPopoverController

/// A few actions in a popover anchored to what was tapped, on iPhone too. It closes before the chosen action runs.
public final class ActionPopoverController: UIViewController {

    // MARK: Types

    public struct Action {

        // MARK: Properties

        let title: String
        let detail: String?
        let image: UIImage?
        let handler: () -> Void

        // MARK: Lifecycle

        public init(title: String, detail: String? = nil, image: UIImage? = nil, handler: @escaping () -> Void) {
            self.title = title
            self.detail = detail
            self.image = image
            self.handler = handler
        }
    }

    // MARK: Static Properties

    private static let width: CGFloat = 320
    private static let minWidth: CGFloat = 180
    /// A list cell's text inset on each side.
    private static let textInset: CGFloat = 20

    // MARK: Properties

    private let actions: [Action]
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private let cell = cellRegistration()

    // MARK: Lifecycle

    public init(actions: [Action], from source: any UIPopoverPresentationControllerSourceItem) {
        self.actions = actions
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .popover
        popoverPresentationController?.sourceItem = source
        popoverPresentationController?.permittedArrowDirections = [.up, .down]
        popoverPresentationController?.delegate = self
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        fitContent()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (controller: Self, _) in
            controller.fitContent()
        }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Static Functions

    private static func cellRegistration() -> UICollectionView.CellRegistration<UICollectionViewListCell, Action> {
        UICollectionView.CellRegistration { cell, _, action in
            var content = action.detail == nil ? UIListContentConfiguration.cell() : .subtitleCell()
            content.text = action.title
            content.secondaryText = action.detail
            content.secondaryTextProperties.color = .secondaryLabel
            content.image = action.image
            content.imageProperties.tintColor = .label
            cell.contentConfiguration = content
            cell.accessibilityTraits = .button
            // The popover's glass shows through every row but the one being touched.
            cell.configurationUpdateHandler = { cell, state in
                var background = UIBackgroundConfiguration.listCell().updated(for: state)
                if !state.isHighlighted, !state.isSelected {
                    background.backgroundColor = .clear
                }
                cell.backgroundConfiguration = background
            }
        }
    }

    // MARK: Functions

    private func setupViews() {
        collectionView.backgroundColor = .clear
        collectionView.dataSource = self
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func fitContent() {
        let width = fittingWidth()
        collectionView.frame = CGRect(x: 0, y: 0, width: width, height: 1000)
        collectionView.layoutIfNeeded()
        preferredContentSize = CGSize(width: width, height: collectionView.collectionViewLayout.collectionViewContentSize.height)
    }

    private func fittingWidth() -> CGFloat {
        guard actions.allSatisfy({ $0.detail == nil && $0.image == nil }) else {
            return Self.width
        }
        let font = UIFont.preferredFont(forTextStyle: .body, compatibleWith: traitCollection)
        let widest = actions.map { action in
            TextLayout(text: NSAttributedString(string: action.title, attributes: [.font: font]), numberOfLines: 1)
                .size(fitting: .greatestFiniteMagnitude).width
        }.max() ?? 0
        return min(max(widest + 2 * Self.textInset, Self.minWidth), Self.width)
    }

    private func makeLayout() -> UICollectionViewLayout {
        var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
        configuration.backgroundColor = .clear
        configuration.itemSeparatorHandler = { [count = actions.count] path, separator in
            var separator = separator
            separator.bottomSeparatorVisibility = path.item == count - 1 ? .hidden : .automatic
            return separator
        }
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }
}

// MARK: UICollectionViewDataSource

extension ActionPopoverController: UICollectionViewDataSource {
    public func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        actions.count
    }

    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: actions[indexPath.item])
    }
}

// MARK: UICollectionViewDelegate

extension ActionPopoverController: UICollectionViewDelegate {
    public func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let action = actions[indexPath.item]
        dismiss(animated: true, completion: action.handler)
    }
}

// MARK: UIPopoverPresentationControllerDelegate

extension ActionPopoverController: UIPopoverPresentationControllerDelegate {
    public func adaptivePresentationStyle(for _: UIPresentationController,
                                          traitCollection _: UITraitCollection) -> UIModalPresentationStyle {
        .none
    }
}
