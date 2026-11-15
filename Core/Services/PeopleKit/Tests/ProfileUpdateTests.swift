import CustomDump
import Testing
@testable import PeopleKit

@Suite(.timeLimit(.minutes(1)))
struct ProfileUpdateTests {
    private static let saved = PublicProfile.fixture(
        name: "Rider",
        username: "rider",
        bio: "Ledges.",
        handles: Handles([.instagram: "rider_ig", .website: "https://rider.example"]),
        avatar: .init(key: "photos/a.jpg", thumbhash: "1QcS"),
    )

    @Test
    func `an untouched draft sends nothing`() {
        expectNoDifference(ProfileUpdate(from: Self.saved, to: ProfileDraft(Self.saved)), ProfileUpdate())
    }

    @Test
    func `values are compared the way the server stores them`() {
        var draft = ProfileDraft(Self.saved)
        draft.name = "  Rider "
        draft.username = " rider "
        draft.bio = "Ledges.\n"
        draft.handles[.instagram] = "@rider_ig"

        expectNoDifference(ProfileUpdate(from: Self.saved, to: draft), ProfileUpdate())
    }

    @Test
    func `changes are sent as typed, with their case, and emptied fields become clears`() {
        var draft = ProfileDraft(Self.saved)
        draft.username = " Rider_Two "
        draft.bio = "   "
        draft.handles[.instagram] = ""
        draft.handles[.x] = "@rider_x"
        draft.avatar = .removed

        expectNoDifference(
            ProfileUpdate(from: Self.saved, to: draft),
            ProfileUpdate(username: "Rider_Two", handles: [.x: "rider_x"], clear: [.bio, .avatar, .instagram]),
        )
    }

    @Test
    func `emptying something that was already empty sends nothing`() {
        let bare = PublicProfile.fixture(name: "Rider")
        var draft = ProfileDraft(bare)
        draft.handles[.tiktok] = "  "
        draft.avatar = .removed

        expectNoDifference(ProfileUpdate(from: bare, to: draft), ProfileUpdate())
    }
}
