import ComponentKit
import SpotModelKit

nonisolated struct CollectionFace: Hashable, Sendable {

    // MARK: Computed Properties

    @MainActor
    var title: String {
        kind.title(named: name)
    }

    var pictureKey: String? {
        look.pictureKey(cover: coverKey)
    }

    var pictureThumbhash: String? {
        look.pictureThumbhash(cover: coverThumbhash)
    }

    @MainActor
    var pictureSymbol: String {
        kind.pictureSymbol
    }

    @MainActor
    var backdrop: CollectionHeroView.Backdrop {
        pictureKey.map { .photo(key: $0, thumbhash: pictureThumbhash) } ?? .look(look, symbol: pictureSymbol)
    }

    // MARK: Properties

    var name: String
    var kind: CollectionKind
    var look: CollectionLook
    var coverKey: String?
    var coverThumbhash: String?
}
