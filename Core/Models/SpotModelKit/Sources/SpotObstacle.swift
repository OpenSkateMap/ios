public enum SpotObstacle {

    // MARK: Types

    /// Stored, synced and matched as these lowercase English raw values.
    public enum Common: String, CaseIterable, Sendable {
        case ledges
        case rails
        case stairs
        case banks
        case gaps
        case manualPads = "manual pads"
        case hubbas
        case bowl
        case miniRamp = "mini ramp"
        case quarterPipe = "quarter pipe"
        case flatBars = "flat bars"
        case transitions

        // MARK: Lifecycle

        /// The common obstacle a stored one spells, ignoring case and a plural "s" either way ("gap", "Bowls").
        public init?(stored obstacle: String) {
            let stored = obstacle.lowercased()
            let common = Self.allCases.first { [stored, stored + "s"].contains($0.rawValue) || $0.rawValue + "s" == stored }
            guard let common else {
                return nil
            }
            self = common
        }
    }

    // MARK: Static Properties

    public static let common = Common.allCases.map(\.rawValue)

    // MARK: Static Functions

    /// The chips to pick from: the common ones, each in `chosen`'s spelling where they differ only by a plural "s"
    /// (a spot's "gap" stands in for "gaps", so it doesn't show twice), then the rest of `chosen`.
    public static func choices(including chosen: some Sequence<String>) -> [String] {
        var rest = Set(chosen)
        let chips = Common.allCases.map { common in
            guard let match = rest.first(where: { Common(stored: $0) == common }) else {
                return common.rawValue
            }
            rest.remove(match)
            return match
        }
        return chips + rest.sorted()
    }
}
