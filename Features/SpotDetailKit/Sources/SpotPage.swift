import SpotModelKit
import SQLiteData

// MARK: - SpotPage

struct SpotPage: Equatable {
    var spot: SpotIndex?
    var detail: SpotDetail?
    var photos = [SpotPhoto]()
    var videos = [SpotVideo]()
    var videoDraft: VideoDraft?
    var city: City?
    var isStarred = false
}

// MARK: - SpotPageRequest

struct SpotPageRequest: FetchKeyRequest {
    let id: String?

    private static func isStarred(_ spotID: String, _ db: Database) throws -> Bool {
        guard let favorites = try SpotCollection
            .where({ $0.kind.eq(CollectionKind.favorites) && $0.role.eq(CollectionRole.owner) })
            .select(\.id)
            .fetchOne(db) else {
            return false
        }
        return try SpotCollectionEntry.where { $0.collectionID.eq(favorites) && $0.spotID.eq(spotID) }.fetchCount(db) > 0
    }

    func fetch(_ db: Database) throws -> SpotPage {
        guard let id, let spot = try SpotIndex.find(id).fetchOne(db) else {
            return SpotPage()
        }
        return try SpotPage(
            spot: spot,
            detail: SpotDetail.find(id).fetchOne(db),
            photos: SpotPhoto.where { $0.spotID.eq(id) }.order(by: \.position).fetchAll(db),
            videos: SpotVideo.where { $0.spotID.eq(id) }.order(by: \.position).fetchAll(db),
            videoDraft: VideoDraft.where { $0.spotID.eq(id) }.order { $0.createdAt.desc() }.fetchOne(db),
            city: spot.cityID.flatMap { try City.find($0).fetchOne(db) },
            isStarred: Self.isStarred(id, db),
        )
    }
}
