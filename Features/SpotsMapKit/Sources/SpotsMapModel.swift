import AnalyticsKit
import FactoryKit
import Foundation
import LocationKit
import MapKit
import NotificationsKit
import Observation
import os
import SpotModelKit
import SpotsKit
import SQLiteData
import SQLiteKit

// MARK: - SpotsMapModel

@MainActor
@Observable
final class SpotsMapModel {

    // MARK: Types

    enum FirstLoad: Equatable {
        case loading
        case failed
    }

    // MARK: Static Properties

    private static let settle = Duration.milliseconds(150)
    private static let margin = 1.25
    private static let savedRegionKey = "map.region"
    private static let cityScale = 3.0
    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "map")

    // MARK: Computed Properties

    var citySpots: [CitySpot] {
        cityRows
    }

    /// What pins and lists follow.
    var effectiveFilter: SpotFilter {
        var effective = filter
        effective.spotIDs = collection.map { Set($0.spotIDs) }
        return effective
    }

    var collectionCards: [CollectionCard] {
        storedCards
    }

    var firstLoad: FirstLoad? {
        guard cities.isEmpty else {
            return nil
        }
        if spotsSession.isSyncing || spotsSession.lastOutcome == nil {
            return .loading
        }
        return spotsSession.lastOutcome == .synced ? nil : .failed
    }

    // MARK: Properties

    /// A spot inside `box` but not in `spots` is gone; outside it, unknown.
    private(set) var spots = [SpotIndex]()
    private(set) var box: CoordinateBox?
    private(set) var camera: MapCamera?
    private(set) var showsUserLocation = false
    private(set) var isLocating = false
    private(set) var isOpeningLink = false
    private(set) var notice: MapNotice?
    private(set) var visibleRegion: MKCoordinateRegion?
    private(set) var filter = SpotFilter()
    private(set) var place: DiscoverPlace?
    private(set) var collection: CollectionFocus?
    private(set) var placeMark: MKPointAnnotation?
    /// Set with the rows it was loaded for, so the list's heading never changes a frame before them.
    private(set) var listedCollection: CollectionFocus?

    let selection = SpotSelection()

    @ObservationIgnored @FetchAll(SpotIndex.none) private var viewport
    @ObservationIgnored @FetchAll(City.all) private var cities
    @ObservationIgnored @FetchAll private var cityRows: [CitySpot]
    @ObservationIgnored @Fetch(CollectionCardsRequest()) private var storedCards = []
    @ObservationIgnored @Injected(\.spotsSession) private var spotsSession
    @ObservationIgnored @Injected(\.locationManager) private var locationManager
    @ObservationIgnored @Injected(\.geocodingManager) private var geocoding
    @ObservationIgnored private let recentSpots = RecentSpots()
    @ObservationIgnored @Injected(\.database) private var database
    @ObservationIgnored @Injected(\.notificationsManager) private var notifications
    @ObservationIgnored @Injected(\.analyticsManager) private var analytics
    @ObservationIgnored private var started = false
    @ObservationIgnored private var hasCamera = false
    @ObservationIgnored private var emitting: Task<Void, Never>?
    @ObservationIgnored private var reloading: Task<Void, Never>?
    @ObservationIgnored private var syncing: Task<Void, Never>?
    @ObservationIgnored private var loadedBox: CoordinateBox?
    @ObservationIgnored private var opening: Task<Void, Never>?
    @ObservationIgnored private var listing: Task<Void, Never>?
    @ObservationIgnored private var focusedSpot: SpotIndex?
    @ObservationIgnored private var viewportRows = [SpotIndex]()
    @ObservationIgnored private var adopting: Task<Void, Never>?
    @ObservationIgnored private var naming: Task<Void, Never>?
    @ObservationIgnored private var areaNames = [String: String]()
    @ObservationIgnored private var firstFix: Task<Void, Never>?
    @ObservationIgnored private var followingCollections: Task<Void, Never>?

    // MARK: Lifecycle

    isolated deinit {
        emitting?.cancel()
        reloading?.cancel()
        syncing?.cancel()
        opening?.cancel()
        listing?.cancel()
        adopting?.cancel()
        naming?.cancel()
        firstFix?.cancel()
        followingCollections?.cancel()
    }

    // MARK: Static Functions

    static func box(around region: MKCoordinateRegion, margin: Double = SpotsMapModel.margin) -> CoordinateBox {
        let halfLatitude = region.span.latitudeDelta * margin / 2
        let halfLongitude = min(region.span.longitudeDelta * margin / 2, 180)
        func wrap(_ longitude: Double) -> Double {
            longitude > 180 ? longitude - 360 : longitude < -180 ? longitude + 360 : longitude
        }
        if halfLongitude >= 180 {
            return CoordinateBox(
                south: region.center.latitude - halfLatitude,
                west: -180,
                north: region.center.latitude + halfLatitude,
                east: 180,
            )
        }
        return CoordinateBox(
            south: max(-90, region.center.latitude - halfLatitude),
            west: wrap(region.center.longitude - halfLongitude),
            north: min(90, region.center.latitude + halfLatitude),
            east: wrap(region.center.longitude + halfLongitude),
        )
    }

    private static func region(of city: City) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: (city.minLatitude + city.maxLatitude) / 2,
                longitude: (city.minLongitude + city.maxLongitude) / 2,
            ),
            span: MKCoordinateSpan(
                latitudeDelta: (city.maxLatitude - city.minLatitude) * 0.5,
                longitudeDelta: (city.maxLongitude - city.minLongitude) * 0.5,
            ),
        )
    }

    private static func region(around coordinate: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, latitudinalMeters: 1500, longitudinalMeters: 1500)
    }

    private static func savedRegion() -> MKCoordinateRegion? {
        guard let values = UserDefaults.standard.array(forKey: savedRegionKey) as? [Double], values.count == 4 else {
            return nil
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: values[0], longitude: values[1]),
            span: MKCoordinateSpan(latitudeDelta: values[2], longitudeDelta: values[3]),
        )
    }

    private static func save(_ region: MKCoordinateRegion) {
        UserDefaults.standard.set(
            [region.center.latitude, region.center.longitude, region.span.latitudeDelta, region.span.longitudeDelta],
            forKey: savedRegionKey,
        )
    }

    private static func region(fitting spots: [SpotIndex]) -> MKCoordinateRegion? {
        guard let first = spots.first else {
            return nil
        }
        let latitudes = spots.map(\.latitude)
        let longitudes = spots.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: ((latitudes.min() ?? first.latitude) + (latitudes.max() ?? first.latitude)) / 2,
            longitude: ((longitudes.min() ?? first.longitude) + (longitudes.max() ?? first.longitude)) / 2,
        )
        let latitudeSpan = (latitudes.max() ?? 0) - (latitudes.min() ?? 0)
        let longitudeSpan = (longitudes.max() ?? 0) - (longitudes.min() ?? 0)
        let closeUp = MKCoordinateRegion(center: center, latitudinalMeters: 900, longitudinalMeters: 900).span
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max(latitudeSpan * 1.6, closeUp.latitudeDelta),
                longitudeDelta: max(longitudeSpan * 1.6, closeUp.longitudeDelta),
            ),
        )
    }

    // MARK: Functions

    func start() {
        guard !started else {
            return
        }
        started = true
        // Only the locate button asks; once allowed, the map opens on the person, with the dot.
        showsUserLocation = locationManager.isAuthorized()
        if showsUserLocation, let coordinate = locationManager.lastLocation() {
            hasCamera = true
            camera = MapCamera(region: Self.region(around: coordinate), move: .jump)
        } else if let region = Self.savedRegion() {
            hasCamera = true
            camera = MapCamera(region: region, move: .jump)
        } else {
            camera = MapCamera(planetAt: Double(TimeZone.current.secondsFromGMT()) / 3600 * 15)
        }
        if showsUserLocation {
            moveToFirstFix()
        }
        emitting = Task { [weak self] in
            let rows = Observations { [weak self] in self?.viewport ?? [] }
            for await rows in rows {
                guard let self else {
                    return
                }
                viewportRows = rows
                spots = withFocused(rows)
                box = loadedBox
                try? await Task.sleep(for: Self.settle)
            }
        }
        sync(joining: true)
        adopting = Task { [weak self] in
            for await _ in Observations({ [weak self] in self?.cities.count ?? 0 }) {
                guard let self, hasCamera, let region = visibleRegion else {
                    continue
                }
                adoptPlace(at: region)
            }
        }
        followingCollections = Task { [weak self] in
            var stored = Set<String>()
            for await cards in Observations({ [weak self] in self?.storedCards ?? [] }) {
                await self?.followShownCollection(in: cards, storedBefore: stored)
                stored = Set(cards.map(\.id))
            }
        }
    }

    func regionChanged(_ region: MKCoordinateRegion, byUser: Bool) {
        visibleRegion = region
        if byUser {
            hasCamera = true
            firstFix?.cancel()
        }
        if hasCamera {
            Self.save(region)
            adoptPlace(at: region)
        }
        reloadViewport(after: Self.settle)
    }

    func setFilter(_ filter: SpotFilter) {
        guard filter != self.filter else {
            return
        }
        self.filter = filter
        analytics.capture(.filtersChanged(
            kinds: filter.kinds.count,
            conditions: filter.conditions.count,
            obstacles: filter.obstacles.count,
        ))
        reloadViewport(after: .zero)
        loadCity()
    }

    func count(matching filter: SpotFilter) async -> Int? {
        var narrowed = filter
        narrowed.spotIDs = collection.map { Set($0.spotIDs) }
        switch (collection, place) {
        case (.some, _):
            return try? await database
                .read { [narrowed] db in try SpotIndex.where { _ in true }.matching(narrowed).fetchCount(db) }

        case (nil, .city(let city)?):
            return try? await database
                .read { [narrowed] db in try SpotIndex.where { $0.cityID.eq(city.id) }.matching(narrowed).fetchCount(db) }

        case (nil, .area(_, let box)?):
            return try? await database.read { [narrowed] db in try SpotIndex.within(box).matching(narrowed).fetchCount(db) }

        case (nil, nil):
            return nil
        }
    }

    func show(_ focus: CollectionFocus) {
        collection = focus
        reloadViewport(after: .zero)
        loadCity()
        frame(focus.spotIDs)
    }

    func show(collectionID id: String) {
        Task { [weak self] in
            guard let self, let focus = try? await localFocus(id) else {
                return
            }
            show(focus)
        }
    }

    func clearCollection() {
        collection = nil
        reloadViewport(after: .zero)
        loadCity()
    }

    func showing(_ ids: [String]) {
        spotsSession.show(ids)
    }

    /// `source` is `nil` for the app's own changes (closing, restoring).
    func select(_ id: String?, from source: AnalyticsEvent.SpotSource? = nil, suggestingEdit: Bool = false) {
        // The map selecting the opened spot's pin selects it again: only another spot drops the edit asked for.
        if suggestingEdit {
            selection.suggestsEdit = id != nil
        } else if id != selection.spotID {
            selection.suggestsEdit = false
        }
        selection.spotID = id
        if let id, let source {
            analytics.capture(.spotOpened(spotID: id, from: source))
        }
    }

    func selectionChanged(_ id: String?) {
        if id != nil {
            placeMark = nil
        }
        if let focused = focusedSpot, id != focused.id {
            focusedSpot = nil
            spots = viewportRows
        }
        spotsSession.select(id)
        if let id {
            recentSpots.add(id)
        }
    }

    func focus(on spot: SpotIndex, from source: AnalyticsEvent.SpotSource, suggestingEdit: Bool = false) {
        hasCamera = true
        let center = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        camera = MapCamera(
            region: MKCoordinateRegion(center: center, latitudinalMeters: 900, longitudinalMeters: 900),
            move: .travel,
        )
        focusedSpot = spot
        spots = withFocused(viewportRows)
        select(spot.id, from: source, suggestingEdit: suggestingEdit)
    }

    func open(spotID id: String, suggestingEdit: Bool = false) {
        opening?.cancel()
        isOpeningLink = false
        opening = Task { [weak self] in
            guard let self else {
                return
            }
            do {
                var spot = try await indexedSpot(id)
                if spot == nil {
                    isOpeningLink = true
                    await spotsSession.syncNow()
                    // A newer link owns the flag once this one is cancelled.
                    if !Task.isCancelled {
                        isOpeningLink = false
                    }
                    guard spotsSession.lastOutcome == .synced else {
                        if !Task.isCancelled {
                            notice = .spotUnavailable
                        }
                        return
                    }
                    spot = try await indexedSpot(id)
                }
                guard !Task.isCancelled else {
                    return
                }
                if let spot {
                    focus(on: spot, from: .link, suggestingEdit: suggestingEdit)
                } else {
                    notice = .spotNotFound
                }
            } catch {
                Self.logger.error("Looking up a linked spot failed: \(String(describing: type(of: error)), privacy: .public)")
                if !Task.isCancelled {
                    notice = .spotUnavailable
                }
            }
        }
    }

    func focus(onPlace region: MKCoordinateRegion, mark: MKPointAnnotation) {
        analytics.capture(.placeOpened)
        placeMark = mark
        hasCamera = true
        camera = MapCamera(region: region, move: .travel)
    }

    func clearPlaceMark() {
        placeMark = nil
    }

    func locate() {
        guard !isLocating else {
            return
        }
        isLocating = true
        Task {
            defer { isLocating = false }
            do {
                let coordinate = try await locationManager.currentLocation()
                showsUserLocation = true
                hasCamera = true
                camera = MapCamera(region: Self.region(around: coordinate), move: .travel)
            } catch LocationError.denied {
                notice = .locationDenied
            } catch {
                notice = .locationUnavailable
            }
        }
    }

    func dismissNotice() {
        notice = nil
    }

    func retrySync() {
        sync(joining: false)
    }

    func cityName(for spot: SpotIndex) -> String? {
        cities.first { $0.id == spot.cityID }?.localizedName
    }

    /// The collection shown is a copy: one of the account's own that has gone (deleted here or elsewhere, or left)
    /// lets go of the map, and one that changed shows its new name and spots. One opened from a link was never stored.
    private func followShownCollection(in cards: [CollectionCard], storedBefore: Set<String>) async {
        guard let shown = collection?.id else {
            return
        }
        guard cards.contains(where: { $0.id == shown }) else {
            if storedBefore.contains(shown) {
                clearCollection()
            }
            return
        }
        guard let fresh = try? await localFocus(shown), collection?.id == shown, fresh != collection else {
            return
        }
        collection = fresh
        reloadViewport(after: .zero)
        loadCity()
    }

    private func sync(joining: Bool) {
        syncing = Task { [weak self] in
            await self?.spotsSession.syncNow(joining: joining)
            await self?.frameBusiestCityIfNeeded()
        }
    }

    /// The last fix may be from before a trip. A fresh one moves the map, unless the person or something else already has.
    private func moveToFirstFix() {
        let launchCamera = camera
        firstFix = Task { [weak self] in
            guard let coordinate = try? await self?.locationManager.currentLocation(), let self, !Task.isCancelled,
                  camera == launchCamera else {
                return
            }
            hasCamera = true
            camera = MapCamera(region: Self.region(around: coordinate), move: .travel)
        }
    }

    private func withFocused(_ rows: [SpotIndex]) -> [SpotIndex] {
        guard let focusedSpot, !rows.contains(where: { $0.id == focusedSpot.id }) else {
            return rows
        }
        return rows + [focusedSpot]
    }

    private func indexedSpot(_ id: String) async throws -> SpotIndex? {
        try await database.read { db in try SpotIndex.find(id).fetchOne(db) }
    }

    private func adoptPlace(at region: MKCoordinateRegion) {
        naming?.cancel()
        guard region.span.latitudeDelta < Self.cityScale else {
            adopt(nil)
            return
        }
        if let found = curatedCity(at: region.center) {
            adopt(.city(found))
            return
        }
        let box = Self.box(around: region, margin: 1)
        naming = Task { [weak self] in
            guard let name = await self?.areaName(at: region.center), let self, !Task.isCancelled else {
                return
            }
            adopt(.area(name: name, box: box))
        }
    }

    /// MapKit rate-limits reverse geocoding, so names are kept per tenth of a degree.
    private func areaName(at center: CLLocationCoordinate2D) async -> String {
        let key = "\((center.latitude * 10).rounded()),\((center.longitude * 10).rounded())"
        if let name = areaNames[key] {
            return name
        }
        guard let place = await geocoding.place(center), let name = place.city ?? place.region else {
            return SpotsMapKitStrings.Discover.thisArea
        }
        areaNames[key] = name
        return name
    }

    private func adopt(_ found: DiscoverPlace?) {
        guard found != place else {
            return
        }
        place = found
        if case .city(let city)? = found {
            notifications.setCity(city.id)
        }
        loadCity()
    }

    private func loadCity() {
        listing?.cancel()
        let filter = effectiveFilter
        listing = Task { [weak self, collection, place] in
            do {
                switch (collection, place) {
                case (.some, _):
                    try await self?.$cityRows.load(SpotIndex.listed(matching: filter), scheduler: .backgroundRead)
                case (nil, .city(let city)?):
                    try await self?.$cityRows.load(SpotIndex.inCity(city.id, matching: filter), scheduler: .backgroundRead)
                case (nil, .area(_, let box)?):
                    try await self?.$cityRows.load(SpotIndex.inArea(box, matching: filter), scheduler: .backgroundRead)
                case (nil, nil):
                    try await self?.$cityRows.load(
                        SpotIndex.listed(matching: SpotFilter(spotIDs: [])),
                        scheduler: .backgroundRead,
                    )
                }
                guard !Task.isCancelled else {
                    return
                }
                self?.listedCollection = collection
            } catch {
                Self.logger.error("Loading the city failed: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
    }

    private func reloadViewport(after delay: Duration) {
        guard let region = visibleRegion else {
            return
        }
        let filter = effectiveFilter
        reloading?.cancel()
        reloading = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard let self, !Task.isCancelled else {
                return
            }
            do {
                let box = Self.box(around: region)
                try await $viewport.load(SpotIndex.inViewport(box, matching: filter), scheduler: .backgroundRead)
                guard !Task.isCancelled else {
                    return
                }
                loadedBox = box
            } catch {
                Self.logger.error("Loading the viewport failed: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
    }

    private func localFocus(_ id: String) async throws -> CollectionFocus? {
        try await database.read { db in
            guard let collection = try SpotCollection.find(id).fetchOne(db) else {
                return nil
            }
            let spotIDs = try SpotCollectionEntry.where { $0.collectionID.eq(id) }.order { $0.position }.select(\.spotID)
                .fetchAll(db)
            return CollectionFocus(id: id, name: collection.name, kind: collection.kind, spotIDs: spotIDs)
        }
    }

    /// One spot gets the same close-up as a picked spot.
    private func frame(_ ids: [String]) {
        Task { [weak self] in
            guard let self, let spots = try? await database.read({ db in try SpotIndex.where { $0.id.in(ids) }.fetchAll(db) }),
                  let region = Self.region(fitting: spots) else {
                return
            }
            hasCamera = true
            camera = MapCamera(region: region, move: .travel)
        }
    }

    private func curatedCity(at center: CLLocationCoordinate2D) -> City? {
        cities
            .filter {
                $0.minLatitude...$0.maxLatitude ~= center.latitude && $0.minLongitude...$0.maxLongitude ~= center.longitude
            }
            .min {
                ($0.maxLatitude - $0.minLatitude) * ($0.maxLongitude - $0.minLongitude) <
                    ($1.maxLatitude - $1.minLatitude) * ($1.maxLongitude - $1.minLongitude)
            }
    }

    private func frameBusiestCityIfNeeded() async {
        guard !hasCamera else {
            return
        }
        let city = try? await database.read { db -> City? in
            let busiest = try SpotIndex
                .where { $0.cityID.isNot(nil) }
                .group(by: \.cityID)
                .order { $0.id.count().desc() }
                .select { $0.cityID }
                .fetchOne(db)
            guard let id = busiest ?? nil else {
                return nil
            }
            return try City.find(id).fetchOne(db)
        }
        guard let city, !hasCamera else {
            return
        }
        hasCamera = true
        camera = MapCamera(region: Self.region(of: city), move: .travel)
    }

}
