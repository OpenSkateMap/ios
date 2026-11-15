import ComponentKit
import PinLayout
import SpotModelKit
import UIKit

// MARK: - FiltersSheet

enum FiltersSheet {

    static func make(filter: SpotFilter,
                     count: @escaping (SpotFilter) async -> Int?,
                     apply: @escaping (SpotFilter) -> Void) -> OptionSheetViewController {
        let filters = FiltersView(filter: filter)
        let sheet = OptionSheetViewController(
            title: SpotsMapKitStrings.Filters.title,
            message: nil,
            content: filters,
            tint: nil,
            confirmTitle: SpotsMapKitStrings.Filters.apply,
        ) { [filters] in apply(filters.filter) }
        var counting: Task<Void, Never>?
        filters.onChange = { [weak sheet] filter in
            counting?.cancel()
            counting = Task {
                let spots = await count(filter)
                guard !Task.isCancelled else {
                    return
                }
                sheet?.setConfirmTitle(spots.map { SpotsMapKitStrings.Filters.show($0) } ?? SpotsMapKitStrings.Filters.apply)
            }
        }
        filters.onChange?(filter)
        return sheet
    }
}

// MARK: - FiltersView

private final class FiltersView: UIView {

    // MARK: Static Properties

    private static let tapTarget: CGFloat = 44

    // MARK: Properties

    var onChange: ((SpotFilter) -> Void)?

    private(set) var filter: SpotFilter

    private var sections = [(header: Label, chips: ToggleChipsView)]()
    private let clearButton = UIButton(configuration: .plain())

    // MARK: Lifecycle

    init(filter: SpotFilter) {
        self.filter = filter
        super.init(frame: .zero)
        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    private func setupViews() {
        addSection(
            SpotsMapKitStrings.Filters.kind,
            values: SpotKind.allCases.map(\.rawValue),
            title: { SpotKind(rawValue: $0)?.title ?? $0 },
            isSelected: { [weak self] in SpotKind(rawValue: $0).map { self?.filter.kinds.contains($0) ?? false } ?? false },
            onToggle: { [weak self] in
                if let kind = SpotKind(rawValue: $0) {
                    self?.change { $0.kinds.formSymmetricDifference([kind]) }
                }
            },
        )
        addSection(
            SpotsMapKitStrings.Filters.condition,
            values: SpotCondition.allCases.map(\.rawValue),
            title: { SpotCondition(rawValue: $0)?.title ?? $0 },
            isSelected: { [weak self] in
                SpotCondition(rawValue: $0).map { self?.filter.conditions.contains($0) ?? false } ?? false
            },
            onToggle: { [weak self] in
                if let condition = SpotCondition(rawValue: $0) {
                    self?.change { $0.conditions.formSymmetricDifference([condition]) }
                }
            },
        )
        addSection(
            SpotsMapKitStrings.Filters.obstacles,
            values: SpotObstacle.choices(including: filter.obstacles),
            title: SpotObstacle.title(of:),
            isSelected: { [weak self] in self?.filter.obstacles.contains($0) ?? false },
            onToggle: { [weak self] obstacle in self?.change { $0.obstacles.formSymmetricDifference([obstacle]) } },
        )
        var clear = UIButton.Configuration.plain()
        clear.title = SpotsMapKitStrings.Filters.clear
        clear.contentInsets = .zero
        clearButton.configuration = clear
        clearButton.addAction(UIAction { [weak self] _ in self?.clearAll() }, for: .primaryActionTriggered)
        addSubview(clearButton)
    }

    private func addSection(_ name: String,
                            values: [String],
                            title: (String) -> String,
                            isSelected: @escaping (String) -> Bool,
                            onToggle: @escaping (String) -> Void) {
        let header = Label()
        header.text = name
        header.font = .preferredFont(forTextStyle: .title3, weight: .semibold)
        header.adjustsFontForContentSizeCategory = true
        header.accessibilityTraits = .header
        let chips = ToggleChipsView(values: values, title: title, isSelected: isSelected, onToggle: onToggle)
        addSubview(header)
        addSubview(chips)
        sections.append((header, chips))
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        var top: CGFloat = 0
        for (header, chips) in sections {
            header.pin
                .top(top)
                .start()
                .width(width)
                .sizeToFit(.width)
            chips.pin
                .below(of: header)
                .start()
                .width(width)
                .marginTop(10)
                .sizeToFit(.width)
            top = chips.frame.maxY + 24
        }
        // As tall as a tap target, its title where a fitted button's would be.
        let fitted = clearButton.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let height = max(fitted.height, Self.tapTarget)
        clearButton.pin
            .top(top - (height - fitted.height) / 2)
            .start()
            .width(fitted.width)
            .height(height)
        return clearButton.frame.maxY
    }

    private func change(_ edit: (inout SpotFilter) -> Void) {
        edit(&filter)
        onChange?(filter)
    }

    private func clearAll() {
        filter = SpotFilter()
        for section in sections {
            section.chips.refresh()
        }
        onChange?(filter)
    }
}
