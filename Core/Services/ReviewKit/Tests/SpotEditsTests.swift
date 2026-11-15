import CustomDump
import SpotModelKit
import Testing
@testable import ReviewKit

@Suite(.timeLimit(.minutes(1)))
struct SpotEditsTests {
    @Test
    func `an untouched draft changes nothing`() {
        let card = ReviewCard.fixture("a")

        #expect(SpotEdits(from: card, to: ReviewDraft(card)).isEmpty)
    }

    @Test
    func `only the fields the curator changed are sent`() {
        let card = ReviewCard.fixture("a")
        var draft = ReviewDraft(card)
        draft.title = "  Undercroft Ledges "
        draft.kind = .plaza
        draft.photoIDs = ["a-p1", "a-p0"]

        expectNoDifference(
            SpotEdits(from: card, to: draft),
            SpotEdits(title: "Undercroft Ledges", kind: .plaza, photoIDs: ["a-p1", "a-p0"]),
        )
    }

    @Test
    func `retyping the same text the way the server stores it isn't an edit`() {
        let card = ReviewCard.fixture("a", title: "Ledges")
        var draft = ReviewDraft(card)
        draft.title = " Ledges\n"
        draft.obstacles = [" Ledges "]

        #expect(SpotEdits(from: card, to: draft).isEmpty)
    }

    @Test
    func `a moved pin sends both coordinates, and map jitter isn't a move`() {
        let card = ReviewCard.fixture("a")
        var jitter = ReviewDraft(card)
        jitter.latitude += 1e-9
        var moved = ReviewDraft(card)
        moved.longitude = -0.1172

        #expect(SpotEdits(from: card, to: jitter).isEmpty)
        expectNoDifference(
            SpotEdits(from: card, to: moved),
            SpotEdits(coordinate: .init(latitude: card.latitude, longitude: -0.1172)),
        )
    }

    @Test
    func `dropping a photo sends the photos to keep`() {
        let card = ReviewCard.fixture("a")
        var draft = ReviewDraft(card)
        draft.photoIDs = ["a-p0"]

        expectNoDifference(SpotEdits(from: card, to: draft), SpotEdits(photoIDs: ["a-p0"]))
    }
}
