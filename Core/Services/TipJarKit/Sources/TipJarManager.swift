import RevenueCat

// MARK: - Tip

public struct Tip: Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var price: String

    public init(id: String, title: String, price: String) {
        self.id = id
        self.title = title
        self.price = price
    }
}

// MARK: - TipOutcome

public enum TipOutcome: Equatable, Sendable {
    case paid
    case cancelled
    /// Ask to Buy: a parent approves it later, and RevenueCat finishes it then.
    case pending
}

// MARK: - TipJarError

public enum TipJarError: Error, Equatable, Sendable {
    case notConfigured
    case unavailable
}

// MARK: - TipJarManager

/// Consumable tips that unlock nothing (App Review 3.1.1 allows tipping the developer).
public struct TipJarManager: Sendable {
    public var configure: @Sendable () -> Void
    public var tips: @Sendable () async throws -> [Tip]
    public var buy: @Sendable (_ id: Tip.ID) async throws -> TipOutcome

    public init(configure: @escaping @Sendable () -> Void,
                tips: @escaping @Sendable () async throws -> [Tip],
                buy: @escaping @Sendable (_ id: Tip.ID) async throws -> TipOutcome) {
        self.configure = configure
        self.tips = tips
        self.buy = buy
    }
}

extension TipJarManager {
    /// RevenueCat's public SDK keys (safe in the app). DEBUG buys from RevenueCat's Test Store, so no money moves.
    #if DEBUG
    private static let apiKey = "test_CWJIaJHuQdzeBufGYmODFUSGKFf"
    #else
    private static let apiKey = "appl_xYuzCTlIdcWCskYbYiyauIycAOp"
    #endif
    private static let offering = "tips"

    public static let live = TipJarManager {
        guard !Purchases.isConfigured else {
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: apiKey)
    } tips: {
        let packages = try await purchases().offerings().offering(identifier: offering)?.availablePackages ?? []
        return packages
            .sorted { $0.storeProduct.price < $1.storeProduct.price }
            .map { Tip(id: $0.identifier, title: $0.storeProduct.localizedTitle, price: $0.storeProduct.localizedPriceString) }
    } buy: { id in
        let sdk = try purchases()
        guard let package = try await sdk.offerings().offering(identifier: offering)?.package(identifier: id) else {
            throw TipJarError.unavailable
        }
        do {
            return try await sdk.purchase(package: package).userCancelled ? .cancelled : .paid
        } catch let error as ErrorCode where error == .purchaseCancelledError {
            return .cancelled
        } catch let error as ErrorCode where error == .paymentPendingError {
            return .pending
        }
    }

    /// `Purchases.shared` traps before `configure()`; this throws instead.
    private static func purchases() throws -> Purchases {
        guard Purchases.isConfigured else {
            throw TipJarError.notConfigured
        }
        return Purchases.shared
    }

    public static let preview = TipJarManager { } tips: {
        [
            Tip(id: "tip_small", title: "Small Tip", price: "$1.99"),
            Tip(id: "tip_medium", title: "Medium Tip", price: "$4.99"),
            Tip(id: "tip_large", title: "Large Tip", price: "$9.99"),
        ]
    } buy: { _ in
        .paid
    }
}
