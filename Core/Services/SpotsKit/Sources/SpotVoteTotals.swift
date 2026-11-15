public import SpotModelKit

// MARK: - SpotVoteTotals

public struct SpotVoteTotals: Equatable, Sendable {

    // MARK: Properties

    public var up: Int
    public var down: Int
    public var mine: SpotVote

    // MARK: Lifecycle

    public init(up: Int = 0, down: Int = 0, mine: SpotVote = .none) {
        self.up = up
        self.down = down
        self.mine = mine
    }

    init(_ detail: SpotDetail) {
        self.init(up: detail.upvotes, down: detail.downvotes, mine: detail.myVote)
    }

    // MARK: Functions

    func voting(_ vote: SpotVote) -> SpotVoteTotals {
        var next = self
        switch mine {
        case .up: next.up -= 1
        case .down: next.down -= 1
        case .none: break
        }
        switch vote {
        case .up: next.up += 1
        case .down: next.down += 1
        case .none: break
        }
        next.up = max(next.up, 0)
        next.down = max(next.down, 0)
        next.mine = vote
        return next
    }
}

extension SpotDetail {
    mutating func setVotes(_ totals: SpotVoteTotals) {
        upvotes = totals.up
        downvotes = totals.down
        myVote = totals.mine
    }
}
