public struct Handles: Equatable, Sendable {

    // MARK: Computed Properties

    public var filled: [(network: HandleNetwork, value: String)] {
        HandleNetwork.allCases.compactMap { network in values[network].map { (network, $0) } }
    }

    // MARK: Properties

    private var values: [HandleNetwork: String]

    // MARK: Lifecycle

    public init(_ values: [HandleNetwork: String] = [:]) {
        self.values = values.filter { !$0.value.isEmpty }
    }

    // MARK: Subscripts

    public subscript(_ network: HandleNetwork) -> String? {
        get { values[network] }
        set { values[network] = newValue?.isEmpty == true ? nil : newValue }
    }
}
