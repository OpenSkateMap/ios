import CollectionsKit
import ComponentKit
import FactoryKit
import Foundation
import Observation
import PhotoUploadKit
import SpotModelKit
import UIKit

/// Saved whole with Done; Cancel drops it.
@MainActor
@Observable
final class CollectionEditModel {

    // MARK: Types

    enum Photo: Equatable {
        case none
        case kept(CollectionPhoto)
        case new(PreparedPhoto, preview: UIImage)
    }

    enum PhotoError: Error {
        case unreadable
    }

    // MARK: Computed Properties

    var backdrop: CollectionHeroView.Backdrop {
        switch (photo, pageBackdrop, hadOwnPhoto) {
        case (.new(_, let preview), _, _): .image(preview)
        case (.kept, .look, _), (.none, .look, _), (.none, _, true): .look(look, symbol: kind.pictureSymbol)
        case (.kept, let page, _), (.none, let page, false): page
        }
    }

    var hasChanges: Bool {
        draft != initial
    }

    var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    private var draft: CollectionDraft {
        let photo: CollectionLookDraft.Photo =
            switch photo {
            case .none: .none
            case .kept(let kept): .kept(kept)
            case .new(let prepared, _): .new(prepared)
            }
        return CollectionDraft(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            about: about.trimmingCharacters(in: .whitespacesAndNewlines),
            visibility: visibility,
            look: CollectionLookDraft(photo: photo),
        )
    }

    // MARK: Properties

    let collectionID: String
    let kind: CollectionKind
    var name: String
    var about: String
    var photo: Photo
    private(set) var isSaving = false
    private(set) var isPreparingPhoto = false

    private let look: CollectionLook
    private let pageBackdrop: CollectionHeroView.Backdrop
    private let hadOwnPhoto: Bool
    private let visibility: CollectionVisibility
    private let initial: CollectionDraft

    @ObservationIgnored @LazyInjected(\.collectionsSession) private var session

    // MARK: Lifecycle

    init(collectionID: String, shown: CollectionModel.Shown, backdrop: CollectionHeroView.Backdrop) {
        self.collectionID = collectionID
        kind = shown.kind
        name = shown.name
        about = shown.about
        look = shown.look
        photo = shown.look.photo.map(Photo.kept) ?? .none
        visibility = shown.visibility
        pageBackdrop = backdrop
        hadOwnPhoto = shown.look.photo != nil
        initial = CollectionDraft(
            name: shown.name,
            about: shown.about,
            visibility: shown.visibility,
            look: CollectionLookDraft(shown.look),
        )
    }

    // MARK: Functions

    func choosePhoto(_ imageData: Data) async throws {
        isPreparingPhoto = true
        defer { isPreparingPhoto = false }
        let prepared = try await session.prepare(photo: imageData)
        // The hero spans the screen, wider than 2048 px on its side, so the whole photo, decoded off the main thread.
        guard let preview = await prepared.preview(maxPixelSide: CGFloat(max(prepared.width, prepared.height))) else {
            throw PhotoError.unreadable
        }
        photo = .new(prepared, preview: preview)
    }

    func save() async throws {
        isSaving = true
        defer { isSaving = false }
        try await session.update(collectionID, to: draft)
    }
}
