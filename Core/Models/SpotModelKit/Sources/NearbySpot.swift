public struct NearbySpot: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public var title: String
    public var kind: SpotKind
    public var distanceMeters: Int

    public init(id: String, title: String, kind: SpotKind, distanceMeters: Int) {
        self.id = id
        self.title = title
        self.kind = kind
        self.distanceMeters = distanceMeters
    }
}
