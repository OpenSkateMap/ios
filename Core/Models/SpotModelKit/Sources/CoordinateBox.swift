/// `west > east` means the box crosses the antimeridian.
public struct CoordinateBox: Equatable, Sendable {
    public var crossesAntimeridian: Bool {
        west > east
    }

    public var south: Double
    public var west: Double
    public var north: Double
    public var east: Double

    public init(south: Double, west: Double, north: Double, east: Double) {
        self.south = south
        self.west = west
        self.north = north
        self.east = east
    }

    public func contains(latitude: Double, longitude: Double) -> Bool {
        guard (south...north).contains(latitude) else {
            return false
        }
        return crossesAntimeridian ? longitude >= west || longitude <= east : (west...east).contains(longitude)
    }
}
