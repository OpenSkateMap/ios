public import Foundation
public import SQLiteData

/// Where the last finished library scan left off: the next one looks only at what changed since, unless access or the
/// spots it matched against changed.
@Table("library_scan")
public struct LibraryScan: Equatable, Sendable {
    public static let rowID = 1

    public let id: Int
    /// An archived `PHPersistentChangeToken`.
    public var changeToken: Data?
    public var isLimited: Bool
    public var spotsDigest: String
    public var scannedAt: Date

    public init(id: Int = LibraryScan.rowID, changeToken: Data?, isLimited: Bool, spotsDigest: String, scannedAt: Date) {
        self.id = id
        self.changeToken = changeToken
        self.isLimited = isLimited
        self.spotsDigest = spotsDigest
        self.scannedAt = scannedAt
    }
}
