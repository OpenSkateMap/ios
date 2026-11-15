import CollectionsKit
import Foundation
import SpotModelKit

nonisolated struct CollectionRow: Equatable, Hashable, Sendable {
    @MainActor
    var subtitle: String {
        let spots = CollectionDetailKitStrings.Collections.Row.spots(spotCount)
        let kind =
            switch (role, visibility) {
            case (.admin, _), (.editor, _), (.viewer, _): CollectionDetailKitStrings.Collections.Row.sharedBy(ownerName)
            case (_, .private) where memberCount > 0: CollectionDetailKitStrings.Collections.Row.sharedWith(memberCount)
            case (_, .private): CollectionDetailKitStrings.Visibility.private
            case (_, .public): CollectionDetailKitStrings.Visibility.public
            }
        return CollectionDetailKitStrings.Collections.Row.subtitle(kind, spots)
    }

    var id: String
    var face: CollectionFace
    var visibility: CollectionVisibility
    var role: CollectionRole
    var ownerName: String
    var spotCount: Int
    var memberCount: Int

    init(_ collection: SpotCollection, spotCount: Int) {
        id = collection.id
        face = CollectionFace(
            name: collection.name,
            kind: collection.kind,
            look: collection.look,
            coverKey: collection.coverKey,
            coverThumbhash: collection.coverThumbhash,
        )
        visibility = collection.visibility
        role = collection.role
        ownerName = collection.ownerName
        self.spotCount = spotCount
        memberCount = collection.memberCount
    }

    init(_ collection: RemoteCollection) {
        id = collection.id
        face = CollectionFace(
            name: collection.name,
            kind: collection.kind,
            look: collection.look,
            coverKey: collection.coverKey,
            coverThumbhash: collection.coverThumbhash,
        )
        visibility = collection.visibility
        role = collection.role
        ownerName = collection.ownerName
        spotCount = collection.spotIDs.count
        memberCount = collection.memberCount
    }
}
