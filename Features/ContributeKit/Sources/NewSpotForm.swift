import ContributionsKit
import CoreLocation
import Foundation
import IdentifiedCollections
import PhotoUploadKit
import ReviewKit
import SpotModelKit

// MARK: - NewSpotForm

struct NewSpotForm: Equatable {

    // MARK: Types

    enum Mode: Equatable {
        case new
        /// Suggest an Edit, starting as the spot is.
        case edit(SpotEditTarget)
        /// Edit Before Approving, starting as the card proposes.
        case review(ReviewCard)
    }

    struct Photo: Identifiable, Equatable {
        /// Already on the server, the spot's or the card's: loaded by key, its credit read-only.
        struct Stored: Equatable {
            let id: String
            let key: String
            let thumbhash: String
            let creditText: String?
            var clipMilliseconds: Int?
        }

        enum Source: Equatable {
            case stored(Stored)
            case new(Added)
        }

        /// A photo the person adds: it loads from the pick, and needs a credit.
        struct Added: Equatable {
            enum State: Equatable {
                case preparing
                case ready(PreparedPhoto)
                case failed
            }

            var prepared: PreparedPhoto? {
                if case .ready(let prepared) = state {
                    prepared
                } else {
                    nil
                }
            }

            var state = State.preparing
            var credit = Credit()
            /// Plays in the photo's place, the prepared photo being its poster.
            var clip: PreparedClip?
        }

        var stored: Stored? {
            if case .stored(let stored) = source {
                stored
            } else {
                nil
            }
        }

        var added: Added? {
            if case .new(let added) = source {
                added
            } else {
                nil
            }
        }

        var thumbhash: String? {
            switch source {
            case .stored(let stored): stored.thumbhash
            case .new(let added): added.prepared?.thumbhash
            }
        }

        var clipMilliseconds: Int? {
            switch source {
            case .stored(let stored): stored.clipMilliseconds
            case .new(let added): added.clip?.durationMs
            }
        }

        let id: UUID
        fileprivate(set) var source: Source

        init(_ added: Added = Added()) {
            id = UUID()
            source = .new(added)
        }

        init(spot photo: SpotPhoto) {
            id = UUID()
            source = .stored(Stored(
                id: photo.id,
                key: photo.key,
                thumbhash: photo.thumbhash,
                creditText: photo.credit.map(ContributeKitStrings.NewSpotCover.Credit.someoneElse),
                clipMilliseconds: photo.clip?.durationMs,
            ))
        }

        init(card photo: ReviewCard.Photo) {
            id = UUID()
            source = .stored(Stored(
                id: photo.id,
                key: photo.key,
                thumbhash: photo.thumbhash,
                creditText: photo.creditText,
                clipMilliseconds: photo.clip?.durationMs,
            ))
        }
    }

    struct Credit: Equatable {
        var isComplete: Bool {
            takenBySubmitter || (!trimmedName.isEmpty && hasPermission)
        }

        var trimmedName: String {
            name.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var takenBySubmitter = true
        var name = ""
        var hasPermission = false
    }

    struct Location: Equatable {
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        var latitude: Double
        var longitude: Double
        var name: String
        var subtitle: String?

        init(coordinate: CLLocationCoordinate2D, name: String, subtitle: String? = nil) {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
            self.name = name
            self.subtitle = subtitle
        }
    }

    enum Requirement: Equatable {
        /// A photo is still loading, or couldn't be read.
        case photosReady
        case photoCredits
        case name
        case location
        case kind
        case change
    }

    // MARK: Static Properties

    /// New photos at once: a new spot's, or an edit's on top of the spot's own.
    static let maxPhotos = 10
    static let maxSpotPhotos = 30
    static let titleLength = 1...120

    // MARK: Computed Properties

    var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var missing: [Requirement] {
        var missing = [Requirement]()
        let added = photos.compactMap(\.added)
        if added.contains(where: { $0.prepared == nil }) {
            missing.append(.photosReady)
        }
        if added.contains(where: { !$0.credit.isComplete }) {
            missing.append(.photoCredits)
        }
        if !Self.titleLength.contains(trimmedTitle.count) {
            missing.append(.name)
        }
        if location == nil {
            missing.append(.location)
        }
        if kind == nil {
            missing.append(.kind)
        }
        if case .edit = mode, changedFields.isEmpty {
            missing.append(.change)
        }
        return missing
    }

    var changedFields: [SpotEditField] {
        guard case .edit(let original) = mode else {
            return []
        }
        var changed = [SpotEditField]()
        if trimmedTitle != original.title {
            changed.append(.title)
        }
        if trimmedAbout != original.about {
            changed.append(.description)
        }
        if kind != original.kind {
            changed.append(.spotKind)
        }
        if obstacles != Set(original.obstacles) {
            changed.append(.obstacles)
        }
        if condition != original.condition {
            changed.append(.condition)
        }
        if let location, location.latitude != original.latitude || location.longitude != original.longitude {
            changed.append(.location)
        }
        if photos.map(\.stored?.id) != original.photos.map(\.id) {
            changed.append(.photos)
        }
        return changed
    }

    var trimmedAbout: String {
        about.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNote: String {
        note.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canSubmit: Bool {
        missing.isEmpty
    }

    var hasChanges: Bool {
        switch mode {
        case .new:
            !photos.isEmpty || !trimmedTitle.isEmpty || location != nil || kind != nil || condition != .skateable
                || !obstacles.isEmpty || !trimmedAbout.isEmpty || !trimmedNote.isEmpty

        case .edit:
            !changedFields.isEmpty || !trimmedNote.isEmpty

        case .review(let card):
            !SpotEdits(from: card, to: draft(of: card)).isEmpty
        }
    }

    var coverThumbhash: String? {
        photos.first?.thumbhash
    }

    /// Approving can't upload, so review adds none.
    var photosLeft: Int {
        if case .review = mode {
            return 0
        }
        return max(min(Self.maxPhotos - photos.count { $0.added != nil }, Self.maxSpotPhotos - photos.count), 0)
    }

    var canAddPhotos: Bool {
        photosLeft > 0
    }

    var orderedObstacles: [String] {
        SpotObstacle.common.filter(obstacles.contains) + obstacles.subtracting(SpotObstacle.common).sorted()
    }

    // MARK: Properties

    private(set) var photos = IdentifiedArrayOf<Photo>()
    var title = ""
    var location: Location?
    var kind: SpotKind?
    var condition = SpotCondition.skateable
    var obstacles = Set<String>()
    var about = ""
    var note = ""
    var collectionID: String?
    let mode: Mode

    // MARK: Lifecycle

    init() {
        mode = .new
    }

    init(editing spot: SpotEditTarget) {
        mode = .edit(spot)
        title = spot.title
        about = spot.about
        kind = spot.kind
        condition = spot.condition
        obstacles = Set(spot.obstacles)
        location = Location(
            coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
            name: spot.address ?? spot.title,
        )
        photos = IdentifiedArray(uniqueElements: spot.photos.map(Photo.init(spot:)))
    }

    init(reviewing card: ReviewCard) {
        mode = .review(card)
        title = card.title
        about = card.about
        kind = card.kind
        condition = card.condition
        obstacles = Set(card.obstacles)
        location = Location(
            coordinate: CLLocationCoordinate2D(latitude: card.latitude, longitude: card.longitude),
            name: card.title,
        )
        photos = IdentifiedArray(uniqueElements: card.photos.map(Photo.init(card:)))
    }

    private static func submission(_ added: Photo.Added) -> NewSpot.Photo? {
        added.prepared.map {
            NewSpot.Photo(
                prepared: $0,
                credit: added.credit.takenBySubmitter
                    ? .submitter
                    : .someoneElse(name: added.credit.trimmedName, sourceURL: nil),
                clip: added.clip,
            )
        }
    }

    // MARK: Functions

    /// A suggested edit's card changes only what it suggests; everything else can be changed.
    func isEditable(_ field: SpotEditField) -> Bool {
        guard case .review(let card) = mode, card.isEdit else {
            return true
        }
        return card.changedFields.contains(field)
    }

    @discardableResult
    mutating func append(_ photo: Photo) -> Bool {
        guard canAddPhotos else {
            return false
        }
        photos.append(photo)
        return true
    }

    mutating func removePhoto(_ id: UUID) {
        photos.remove(id: id)
    }

    mutating func makeCover(_ id: UUID) {
        movePhoto(id, to: 0)
    }

    /// `index` is the photo's place once moved; the first photo is the cover.
    mutating func movePhoto(_ id: UUID, to index: Int) {
        guard let photo = photos.remove(id: id) else {
            return
        }
        photos.insert(photo, at: min(max(index, 0), photos.count))
    }

    /// Only a photo the person adds loads and takes a credit; stored ones stay as they are.
    mutating func updateAddedPhoto(_ id: UUID, _ change: (inout Photo.Added) -> Void) {
        guard var added = photos[id: id]?.added else {
            return
        }
        change(&added)
        photos[id: id]?.source = .new(added)
    }

    func spot() -> NewSpot? {
        guard mode == .new, canSubmit else {
            return nil
        }
        return values(photos: photos.compactMap { $0.added.flatMap(Self.submission) })
    }

    func suggestion() -> SpotEditSuggestion? {
        guard case .edit(let original) = mode, canSubmit, let proposed = values(photos: []) else {
            return nil
        }
        let changed = changedFields
        return SpotEditSuggestion(
            spotID: original.spotID,
            proposed: proposed,
            changedDetails: changed.filter { $0 != .photos },
            photoEdit: changed.contains(.photos)
                ? SpotEditSuggestion.PhotoEdit(
                    order: photos.compactMap { photo in
                        switch photo.source {
                        case .stored(let stored): .kept(id: stored.id)
                        case .new(let added): Self.submission(added).map { .added($0) }
                        }
                    },
                    base: original.photos.map(\.id),
                )
                : nil,
        )
    }

    /// What approving sends: only what the curator changed from the card.
    func approval() -> SpotEdits? {
        guard case .review(let card) = mode, canSubmit else {
            return nil
        }
        return SpotEdits(from: card, to: draft(of: card))
    }

    private func draft(of card: ReviewCard) -> ReviewDraft {
        var draft = ReviewDraft(card)
        draft.title = title
        draft.about = about
        draft.kind = kind ?? card.kind
        // The card's own order is no change; a changed set goes out in chip order, as a new spot's does.
        draft.obstacles = obstacles == Set(card.obstacles) ? card.obstacles : orderedObstacles
        draft.condition = condition
        draft.latitude = location?.latitude ?? card.latitude
        draft.longitude = location?.longitude ?? card.longitude
        draft.photoIDs = photos.compactMap(\.stored?.id)
        return draft
    }

    private func values(photos: [NewSpot.Photo]) -> NewSpot? {
        guard let location, let kind else {
            return nil
        }
        return NewSpot(
            title: trimmedTitle,
            about: trimmedAbout,
            kind: kind,
            obstacles: orderedObstacles,
            condition: condition,
            latitude: location.latitude,
            longitude: location.longitude,
            note: collectionID == nil ? trimmedNote : "",
            collectionID: collectionID,
            photos: photos,
        )
    }

}
