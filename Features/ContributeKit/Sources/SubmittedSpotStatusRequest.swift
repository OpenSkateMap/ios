import Foundation
import SpotModelKit
import SQLiteData

// MARK: - SubmittedSpotStatus

enum SubmittedSpotStatus: Equatable, Sendable {
    case sending
    case waitingForNetwork
    case failed(reason: String)
    case sent
}

// MARK: - SubmittedSpotStatusRequest

struct SubmittedSpotStatusRequest: FetchKeyRequest {
    let id: String

    func fetch(_ db: Database) throws -> SubmittedSpotStatus {
        if let draft = try SubmissionDraft.find(id).fetchOne(db) {
            return SubmittedSpotStatus(draft)
        }
        return try MySubmission.find(id).fetchOne(db) == nil ? .sending : .sent
    }
}

extension SubmittedSpotStatus {
    nonisolated init(_ draft: SubmissionDraft) {
        switch draft.status {
        case .failed: self = .failed(reason: draft.problem ?? ContributeKitStrings.SpotSubmitted.Failed.defaultReason)
        case .uploading: self = .sending
        case .pending: self = draft.attempts > 0 ? .waitingForNetwork : .sending
        }
    }
}
