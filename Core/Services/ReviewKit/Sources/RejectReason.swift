public enum RejectReason: String, CaseIterable, Equatable, Sendable {
    case duplicate
    case notASpot = "not_a_spot"
    case wrongLocation = "wrong_location"
    case privateProperty = "private_property"
    case photoRights = "photo_rights"
}
