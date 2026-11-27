import ContributionsKit
import Foundation
import SpotModelKit
import SQLiteData

// MARK: - SubmittedSpotStatus

enum SubmittedSpotStatus: Equatable, Sendable {
    case sending
    case waitingForNetwork
    case failed(reason: String)
    /// `spotID` is the spot it's for: the one edited, or a new one once it's published.
    case sent(spotID: String?)

    var spotID: String? {
        if case .sent(let spotID) = self {
            return spotID
        }
        return nil
    }
}

// MARK: - SubmittedSpotStatusRequest

struct SubmittedSpotStatusRequest: FetchKeyRequest {
    let id: String

    func fetch(_ db: Database) throws -> SubmittedSpotStatus {
        if let draft = try SubmissionDraft.find(id).fetchOne(db) {
            return SubmittedSpotStatus(draft)
        }
        return try MySubmission.find(id).fetchOne(db).map { .sent(spotID: $0.spotID) } ?? .sending
    }
}

extension SubmittedSpotStatus {
    nonisolated init(_ draft: SubmissionDraft) {
        switch draft.status {
        case .failed: self = .failed(reason: draft.problem?.message ?? ContributeKitStrings.SpotSubmitted.Failed.defaultReason)
        case .uploading: self = .sending
        case .pending: self = draft.attempts > 0 ? .waitingForNetwork : .sending
        }
    }
}
