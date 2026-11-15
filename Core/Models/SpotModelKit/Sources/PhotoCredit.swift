public import Foundation

public enum PhotoCredit: Equatable, Codable, Sendable {
    case submitter
    case someoneElse(name: String, sourceURL: URL?)
}
