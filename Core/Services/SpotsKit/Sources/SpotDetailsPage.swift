public struct SpotDetailsPage: Equatable, Sendable {
    public var spots: [RemoteSpotDetail]
    public var missing: [String]

    public init(spots: [RemoteSpotDetail], missing: [String]) {
        self.spots = spots
        self.missing = missing
    }
}
