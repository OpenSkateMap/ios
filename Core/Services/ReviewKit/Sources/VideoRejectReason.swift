public enum VideoRejectReason: String, CaseIterable, Equatable, Sendable {
    case duplicate
    case wrongSpot = "wrong_spot"
    case notSkating = "not_skating"
    case inappropriate
}
