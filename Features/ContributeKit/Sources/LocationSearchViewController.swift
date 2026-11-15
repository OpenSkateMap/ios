import ComponentKit
import FactoryKit
import LocationKit
import MapKit
import os
import PinLayout
import UIKit

// MARK: - LocationSearchViewController

final class LocationSearchViewController: UIViewController {

    // MARK: Types

    enum Choice {
        case place(NewSpotForm.Location)
        case dropPin
    }

    private enum Section: Int, CaseIterable {
        case actions
        case results
    }

    private enum Lookup: Equatable {
        case myLocation
        case place(MKLocalSearchCompletion)
    }

    private enum Action: Int, CaseIterable {
        case myLocation
        case dropPin

        var title: String {
            switch self {
            case .myLocation: ContributeKitStrings.LocationSearch.myLocation
            case .dropPin: ContributeKitStrings.LocationSearch.dropPin
            }
        }

        var symbolName: String {
            switch self {
            case .myLocation: "location.fill"
            case .dropPin: "mappin.and.ellipse"
            }
        }
    }

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "new-spot")

    // MARK: Properties

    @Injected(\.locationManager) private var location
    @Injected(\.geocodingManager) private var geocoding

    private let onChoose: (Choice) -> Void
    private let near: CLLocationCoordinate2D?
    private let query: String?
    private let searchField = UISearchTextField()
    private let closeButton = UIButton(configuration: .glass())
    private let tableView = UITableView(frame: .zero, style: .plain).softEdges()
    private let completer = MKLocalSearchCompleter()
    private var results = [MKLocalSearchCompletion]()
    private var resolving: Task<Void, Never>?
    private var lookup: Lookup? {
        didSet {
            tableView.reloadData()
        }
    }

    // MARK: Lifecycle

    init(near: CLLocationCoordinate2D?, query: String? = nil, onChoose: @escaping (Choice) -> Void) {
        self.near = near
        self.query = query
        self.onChoose = onChoose
        super.init(nibName: nil, bundle: nil)
        sheetPresentationController?.detents = [.large()]
        sheetPresentationController?.prefersGrabberVisible = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        resolving?.cancel()
        completer.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupActions()
        setupCompleter()
        if let query, !query.isEmpty {
            searchField.text = query
            queryChanged()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        searchField.becomeFirstResponder()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let fieldHeight = max(44, ceil(searchField.font?.lineHeight ?? 0) + 22)
        closeButton.pin
            .top(20 + (fieldHeight - 44) / 2)
            .end(16)
            .size(44)
        searchField.pin
            .top(20)
            .start(16)
            .before(of: closeButton)
            .height(fieldHeight)
            .marginEnd(10)
        tableView.pin
            .below(of: searchField)
            .bottom()
            .horizontally()
            .marginTop(12)
    }

    // MARK: Overrides

    override func accessibilityPerformEscape() -> Bool {
        dismiss(animated: true)
        return true
    }

    // MARK: Static Functions

    static func place(at coordinate: CLLocationCoordinate2D, address: String?, fallback: String) -> NewSpotForm.Location {
        let parts = (address ?? "").split(separator: ", ", maxSplits: 1).map(String.init)
        guard let first = parts.first, !first.isEmpty else {
            return NewSpotForm.Location(coordinate: coordinate, name: fallback)
        }
        return NewSpotForm.Location(coordinate: coordinate, name: first, subtitle: parts.count > 1 ? parts[1] : nil)
    }

    // MARK: Functions

    private func setupViews() {
        view.backgroundColor = .systemBackground
        searchField.font = .preferredFont(forTextStyle: .body)
        searchField.adjustsFontForContentSizeCategory = true
        searchField.placeholder = ContributeKitStrings.LocationSearch.placeholder
        searchField.returnKeyType = .search
        searchField.autocorrectionType = .no
        closeButton.configuration?.image = UIImage(systemName: "xmark")
        closeButton.configuration?.cornerStyle = .capsule
        closeButton.accessibilityLabel = ContributeKitStrings.LocationSearch.A11y.close
        tableView.dataSource = self
        tableView.delegate = self
        tableView.keyboardDismissMode = .onDrag
        tableView.backgroundColor = .clear
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        for subview in [searchField, closeButton, tableView] {
            view.addSubview(subview)
        }
    }

    private func setupActions() {
        searchField.addAction(UIAction { [weak self] _ in self?.queryChanged() }, for: .editingChanged)
        closeButton.addAction(UIAction { [weak self] _ in self?.dismiss(animated: true) }, for: .primaryActionTriggered)
    }

    private func setupCompleter() {
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        completer.region = MKCoordinateRegion(
            center: near ?? MKCoordinateRegion.lastMap().center,
            latitudinalMeters: 30000,
            longitudinalMeters: 30000,
        )
    }

    private func queryChanged() {
        let query = searchField.text?.trimmingCharacters(in: .whitespaces) ?? ""
        if query.isEmpty {
            completer.cancel()
            results = []
            tableView.reloadData()
        } else {
            completer.queryFragment = query
        }
    }

    private func choose(_ choice: Choice) {
        let onChoose = onChoose
        dismiss(animated: true) { onChoose(choice) }
    }

    private func useMyLocation() {
        resolving?.cancel()
        lookup = .myLocation
        resolving = Task { [location, geocoding, weak self] in
            do {
                let coordinate = try await location.currentLocation()
                let address = await geocoding.address(coordinate)
                guard !Task.isCancelled, let self else {
                    return
                }
                lookup = nil
                choose(.place(Self.place(
                    at: coordinate,
                    address: address,
                    fallback: ContributeKitStrings.LocationSearch.myLocationName,
                )))
            } catch let error as LocationError {
                Self.logger.notice("No current location: \(String(describing: error), privacy: .public)")
                guard !Task.isCancelled, let self else {
                    return
                }
                lookup = nil
                error.show(from: self)
            } catch {
                // Cancelled by a newer choice.
            }
        }
    }

    private func resolve(_ completion: MKLocalSearchCompletion) {
        resolving?.cancel()
        lookup = .place(completion)
        resolving = Task { [weak self] in
            let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
            // MKLocalSearch doesn't stop when its task is cancelled: a newer choice replaced this one.
            let item = try? await search.start().mapItems.first
            guard !Task.isCancelled, let self else {
                return
            }
            lookup = nil
            guard let item else {
                ToastView.showFailure(
                    ContributeKitStrings.LocationSearch.NotFound.title,
                    subtitle: ContributeKitStrings.LocationSearch.NotFound.message,
                )
                return
            }
            let subtitle = completion.subtitle.isEmpty ? nil : completion.subtitle
            choose(.place(NewSpotForm.Location(
                coordinate: item.location.coordinate,
                name: completion.title,
                subtitle: subtitle,
            )))
        }
    }

    private func spinner() -> UIActivityIndicatorView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        return spinner
    }
}

// MARK: UITableViewDataSource, UITableViewDelegate

extension LocationSearchViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in _: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(rawValue: section) {
        case .actions: Action.allCases.count
        case .results: results.count
        case nil: 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        var content = UIListContentConfiguration.subtitleCell()
        content.imageProperties.tintColor = .secondaryLabel
        content.secondaryTextProperties.color = .secondaryLabel
        var isLookingUp = false
        if Section(rawValue: indexPath.section) == .actions, let action = Action(rawValue: indexPath.row) {
            content.text = action.title
            content.image = UIImage(systemName: action.symbolName)
            content.imageProperties.tintColor = .tintColor
            isLookingUp = action == .myLocation && lookup == .myLocation
        } else if indexPath.row < results.count {
            let result = results[indexPath.row]
            content.text = result.title
            content.secondaryText = result.subtitle.isEmpty ? nil : result.subtitle
            content.image = UIImage(systemName: "mappin.circle.fill")
            isLookingUp = lookup == .place(result)
        }
        cell.contentConfiguration = content
        cell.accessoryView = isLookingUp ? spinner() : nil
        cell.backgroundColor = .clear
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        switch Section(rawValue: indexPath.section) {
        case .actions:
            switch Action(rawValue: indexPath.row) {
            case .myLocation: useMyLocation()
            case .dropPin: choose(.dropPin)
            case nil: break
            }

        case .results:
            if indexPath.row < results.count {
                resolve(results[indexPath.row])
            }

        case nil:
            break
        }
    }
}

// MARK: MKLocalSearchCompleterDelegate

extension LocationSearchViewController: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
        tableView.reloadData()
    }

    func completer(_: MKLocalSearchCompleter, didFailWithError error: any Error) {
        Self.logger.notice("Search suggestions failed: \(String(describing: type(of: error)), privacy: .public)")
    }
}
