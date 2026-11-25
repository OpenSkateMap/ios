public import SpotModelKit

extension OutboxProblem {
    /// What people read for it: Your Spots, Spot Submitted and a spot's videos.
    public var message: String {
        switch self {
        case .photo: ContributionsKitStrings.Outbox.Problem.photo
        case .clip: ContributionsKitStrings.Outbox.Problem.clip
        case .refused: ContributionsKitStrings.Outbox.Problem.refused
        case .device: ContributionsKitStrings.Outbox.Problem.device
        case .video: ContributionsKitStrings.Outbox.Problem.video
        case .videoAlreadyThere: ContributionsKitStrings.Outbox.Problem.videoAlreadyThere
        }
    }
}
