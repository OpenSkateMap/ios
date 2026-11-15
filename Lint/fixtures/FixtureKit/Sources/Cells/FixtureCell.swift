// Lint fixture, never compiled. `mise run ios:lint` expects exactly the violations named by a
// standalone `// expect: <rule>` comment, on the next line of code; every other line stays silent.

// expect: no_combine
import Combine

final class FixtureCell: UICollectionViewCell {
    // expect: container_default_in_signature
    init(service _: FixtureService = Container.shared.fixtureService()) {
        super.init(frame: .zero)
        configure(store: Container.shared.fixtureStore())
        // register(observation: observe { a comment })
        let text = "register(observation: observe { a string }"
        // expect: nsobject_observe_in_cell
        register(observation: observe { [weak self] in _ = self })
        register(observation: SwiftNavigation.observe { [weak self] in _ = self })
        // layer.shadowOpacity = 0.2
        // expect: layer_shadow_in_cell
        layer.shadowRadius = 4
        // print("a comment")
        let quote = "print(a string)"
        // expect: print_in_sources
        print(text, quote)
        // expect: print_in_sources
        NSLog("%@", text)
        // swiftlint:disable:next print_in_sources - fixture for a documented suppression
        print("suppressed")
    }
}

// expect: container_default_in_signature
func named(service store: FixtureService = Container.shared.fixtureService()) {
    _ = store
}

final class FixtureHolder {
    static let shared: FixtureService = Container.shared.fixtureService()
    var other: FixtureService = Container.shared.fixtureService()
    // AnyPublisher in a comment stays silent
    let label = "CurrentValueSubject in a string"
    // expect: no_combine
    var values: AnyPublisher<Int, Never>
    // @Published in a comment stays silent
    let wrapper = "@Dependency and @Published in a string stay silent"
    // expect: no_published
    @Published var count = 0
    // expect: no_dependency_property_wrapper
    @Dependency(\.defaultDatabase) var database
}

func layout(view: UIView, superview: UIView) {
    // view.translatesAutoresizingMaskIntoConstraints = false in a comment
    // expect: no_auto_layout
    view.translatesAutoresizingMaskIntoConstraints = false
    // expect: no_auto_layout
    view.topAnchor.constraint(equalTo: superview.topAnchor).isActive = true
    // expect: no_auto_layout
    NSLayoutConstraint.activate([])
    view.pin.all()
}

final class FixtureScrollViews {
    // expect: soft_scroll_edges
    let plain = UIScrollView()
    // expect: soft_scroll_edges
    lazy var grid = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
    // expect: soft_scroll_edges
    let notes = UITextView()
    let soft = UIScrollView().softEdges()
    lazy var softGrid = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    let table = UITableView(frame: .zero, style: .plain).softEdges()
    // UIScrollView() in a comment stays silent
    let name = "UITableView() in a string"
}

func makeLabels() -> [UIView] {
    // expect: uilabel_instance
    let plain = UILabel()
    let measured = Label()
    return [plain, measured]
}
