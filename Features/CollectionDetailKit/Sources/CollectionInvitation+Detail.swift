import SpotModelKit

extension CollectionInvitation {
    var detail: String {
        let from = inviterName ?? ownerUsername.map { "@\($0)" } ?? ownerName
        return CollectionDetailKitStrings.Collection.Invitation.detail(from, role.title)
    }
}
