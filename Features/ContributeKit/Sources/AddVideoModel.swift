import ContributionsKit
import Foundation
import Observation

@MainActor
@Observable
final class AddVideoModel {

    // MARK: Types

    enum LinkState: Equatable {
        case empty
        case unfinished
        case invalid
        case checking(VideoLink)
        case checked(VideoLink, VideoLinkStatus)
    }

    // MARK: Computed Properties

    var sendableLink: VideoLink? {
        guard case .checked(let link, let status) = state, status != .unavailable else {
            return nil
        }
        return link
    }

    // MARK: Properties

    private(set) var state = LinkState.empty

    @ObservationIgnored private let checker: VideoLinkChecker
    @ObservationIgnored private var checking: Task<Void, Never>?

    // MARK: Lifecycle

    init(checker: VideoLinkChecker) {
        self.checker = checker
    }

    isolated deinit {
        checking?.cancel()
    }

    // MARK: Functions

    func setLinkText(_ text: String, isEditing: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let link = VideoLink(string: trimmed) else {
            checking?.cancel()
            checking = nil
            state = trimmed.isEmpty ? .empty : isEditing ? .unfinished : .invalid
            return
        }
        switch state {
        case .checking(link), .checked(link, _):
            return

        default:
            break
        }
        checking?.cancel()
        state = .checking(link)
        checking = Task { [checker] in
            let status = await checker.check(link)
            guard !Task.isCancelled, state == .checking(link) else {
                return
            }
            state = .checked(link, status)
        }
    }

    func settle() async {
        await checking?.value
    }
}
