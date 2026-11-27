import FactoryKit
import LibraryMatchKit
import Observation
import SpotModelKit
import SQLiteData

/// Contribute's "From Your Photos": what the section shows for the library scan's phase and the matches waiting.
@MainActor
@Observable
final class FromYourPhotosModel {

    // MARK: Nested Types

    enum Content: Equatable {
        case hidden
        case prompt(Prompt)
        /// `note` sits under the cards.
        case matches([LibraryMatchCard], note: Prompt?)

        var prompt: Prompt? {
            switch self {
            case .hidden: nil
            case .prompt(let prompt): prompt
            case .matches(_, let note): note
            }
        }
    }

    enum Prompt: Equatable {
        /// Before access: what it does, and Find My Shots.
        case intro
        case denied
        case scanning(progress: Double)
        case nothingFound
        /// Looking only at the photos the person shared, with a way to Settings.
        case limited(nothingFound: Bool)
    }

    // MARK: Computed Properties

    var content: Content {
        Self.content(for: session.phase, matches: matches)
    }

    // MARK: Properties

    @ObservationIgnored @Fetch(LibraryMatchesRequest()) var matches = [LibraryMatchCard]()

    @ObservationIgnored @Injected(\.libraryMatchSession) private var session

    // MARK: Static Functions

    static func content(for phase: LibraryMatchSession.Phase, matches: [LibraryMatchCard]) -> Content {
        switch phase {
        case .notAsked: .prompt(.intro)
        // Matches found before access was taken away can't show their photos.
        case .denied: .prompt(.denied)
        case .unknown: matches.isEmpty ? .hidden : .matches(matches, note: nil)
        case .scanning(let progress): matches.isEmpty ? .prompt(.scanning(progress: progress)) : .matches(matches, note: nil)
        case .ready: matches.isEmpty ? .prompt(.nothingFound) : .matches(matches, note: nil)
        case .limited: matches.isEmpty ? .prompt(.limited(nothingFound: true)) : .matches(matches, note: .limited(nothingFound: false))
        }
    }

    // MARK: Functions

    func refresh() async {
        await session.refresh()
    }

    func findMyShots() async {
        await session.findMyShots()
    }

    func skip(_ id: LibraryMatch.ID) async {
        await session.skip(id)
    }
}
