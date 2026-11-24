import SpotModelKit

struct GalleryPhoto: Equatable {

    // MARK: Properties

    let key: String?
    let thumbhash: String?
    let credit: String?
    let clip: SpotClip?

    // MARK: Static Functions

    static func pages(of spot: SpotIndex, photos: [SpotPhoto]) -> [GalleryPhoto] {
        let cover = spot.coverKey.flatMap { key in photos.first { $0.key == key } }
        let first = spot.coverKey != nil || spot.coverThumbhash != nil
            ? [GalleryPhoto(key: spot.coverKey, thumbhash: spot.coverThumbhash, credit: cover?.credit, clip: cover?.clip)]
            : []
        let rest = photos.filter { spot.coverKey == nil || $0.key != spot.coverKey }
            .map { GalleryPhoto(key: $0.key, thumbhash: $0.thumbhash, credit: $0.credit, clip: $0.clip) }
        return first + rest
    }
}
