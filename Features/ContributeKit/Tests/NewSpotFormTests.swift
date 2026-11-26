import ContributionsKit
import CoreLocation
import CustomDump
import Foundation
import IdentifiedCollections
import PhotoUploadKit
import ReviewKit
import SpotModelKit
import Testing
@testable import ContributeKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct NewSpotFormTests {

    private static let wellLedgesPhotos = [
        SpotPhoto(
            id: "cover",
            spotID: "spot-1",
            key: "photos/a.jpg",
            width: 4,
            height: 3,
            thumbhash: "1QcSHQRnh493V4dIh4eXh1h4kJUI",
            credit: "Dima",
            position: 0,
        ),
        SpotPhoto(
            id: "second",
            spotID: "spot-1",
            key: "photos/b.jpg",
            width: 4,
            height: 3,
            thumbhash: "2QcSHQRnh493V4dIh4eXh1h4kJUI",
            credit: nil,
            position: 1,
        ),
    ]

    private static let wellLedges = SpotEditTarget(
        spotID: "spot-1",
        title: "Well Ledges",
        about: "Marble ledges",
        kind: .plaza,
        obstacles: ["ledges", "pool coping"],
        condition: .skateable,
        latitude: 51.5066,
        longitude: -0.1169,
        address: "Belvedere Road, London",
        photos: wellLedgesPhotos,
    )

    private static let newSpotCard = ReviewCard(
        id: "card",
        title: "Vauxhall DIY Bowl",
        about: "A concrete bowl under the railway.",
        kind: .diy,
        obstacles: ["quarter pipe", "bowl"],
        condition: .skateable,
        latitude: 51.486,
        longitude: -0.124,
        cityID: "london",
        note: "Built it last summer",
        photos: ["p0", "p1", "p2"].map(cardPhoto),
        submitterName: "Bristol Barry",
        nearby: [NearbySpot(id: "spot-9", title: "Vauxhall Ledges", kind: .street, distanceMeters: 60)],
        createdAt: Date(timeIntervalSince1970: 1_791_633_600),
        updatedAt: Date(timeIntervalSince1970: 1_791_633_600),
    )

    // MARK: Static Functions

    private nonisolated static func cardPhoto(_ id: String) -> ReviewCard.Photo {
        ReviewCard.Photo(
            id: id,
            key: "photos/\(id).jpg",
            width: 4,
            height: 3,
            thumbhash: "1QcSHQRnh493V4dIh4eXh1h4kJUI",
            credit: .submitter,
            isExisting: false,
        )
    }

    private static func editCard(changing fields: [SpotEditField]) -> ReviewCard {
        var card = newSpotCard
        card.spotID = "spot-1"
        card.changedFields = fields
        card.nearby = []
        return card
    }

    private static func prepared(_ tag: UInt8) -> PreparedPhoto {
        PreparedPhoto(jpeg: Data([0xFF, 0xD8, tag]), width: 2048, height: 1536, thumbhash: "VHkKLYyId4eAeHd3h2h3iHdweAeH")
    }

    private static func readyPhoto(_ tag: UInt8, credit: NewSpotForm.Credit = NewSpotForm.Credit()) -> NewSpotForm.Photo {
        NewSpotForm.Photo(NewSpotForm.Photo.Added(state: .ready(prepared(tag)), credit: credit))
    }

    private static func complete() -> NewSpotForm {
        var form = NewSpotForm()
        form.append(readyPhoto(1))
        form.title = "Southbank Undercroft"
        form.location = NewSpotForm.Location(
            coordinate: CLLocationCoordinate2D(latitude: 51.5066, longitude: -0.1169),
            name: "Southbank Centre",
            subtitle: "Belvedere Road, London",
        )
        form.kind = .plaza
        return form
    }

    // MARK: Functions

    @Test
    func `an edit starts as the spot, its photos included, and can't be sent until something changes`() {
        let form = NewSpotForm(editing: Self.wellLedges)

        expectNoDifference(form.title, "Well Ledges")
        expectNoDifference(form.location?.name, "Belvedere Road, London")
        expectNoDifference(form.photos.map(\.stored?.id), Self.wellLedgesPhotos.map(\.id))
        expectNoDifference(form.photos.map(\.stored?.creditText), ["By Dima", nil])
        expectNoDifference(form.missing, [.change])
        expectNoDifference(form.changedFields, [])
        #expect(!form.canSubmit)
        #expect(!form.hasChanges)
        #expect(form.suggestion() == nil)
        #expect(form.spot() == nil)
        expectNoDifference(form.coverThumbhash, Self.wellLedgesPhotos[0].thumbhash)
        expectNoDifference(NewSpotViewController.missingHint(form.missing), "To send, change something or add a photo")
    }

    @Test
    func `an edit sends only what differs, keeps the spot's own obstacles, and counts added photos`() throws {
        var form = NewSpotForm(editing: Self.wellLedges)
        form.condition = .knobbed
        form.title = " Well Ledges "

        expectNoDifference(form.changedFields, [.condition])
        expectNoDifference(form.orderedObstacles, ["ledges", "pool coping"])
        let suggestion = try #require(form.suggestion())
        expectNoDifference(suggestion.spotID, "spot-1")
        expectNoDifference(suggestion.changedFields, [.condition])
        expectNoDifference(suggestion.proposed.obstacles, ["ledges", "pool coping"])
        expectNoDifference(suggestion.photoEdit, nil)

        form.obstacles.remove("pool coping")
        form.append(Self.readyPhoto(3))
        expectNoDifference(form.changedFields, [.obstacles, .condition, .photos])
        #expect(form.hasChanges)
        let withPhoto = try #require(form.suggestion())
        expectNoDifference(withPhoto.changedFields, [.obstacles, .condition, .photos])
        expectNoDifference(
            withPhoto.photoEdit?.order,
            [.kept(id: "cover"), .kept(id: "second"), .added(NewSpot.Photo(prepared: Self.prepared(3), credit: .submitter))],
        )
        expectNoDifference(withPhoto.proposed.photos, [])
    }

    @Test
    func `an edit reorders, removes and adds the spot's photos, and sends them as it leaves them`() throws {
        var form = NewSpotForm(editing: Self.wellLedges)
        let cover = form.photos[0].id
        let second = form.photos[1].id

        form.makeCover(second)
        expectNoDifference(form.changedFields, [.photos])
        expectNoDifference(form.coverThumbhash, Self.wellLedgesPhotos[1].thumbhash)
        form.makeCover(cover)
        expectNoDifference(form.changedFields, [])

        form.removePhoto(cover)
        let added = Self.readyPhoto(4)
        form.append(added)
        form.makeCover(added.id)
        let suggestion = try #require(form.suggestion())
        expectNoDifference(suggestion.changedFields, [.photos])
        expectNoDifference(
            suggestion.photoEdit,
            SpotEditSuggestion.PhotoEdit(
                order: [.added(NewSpot.Photo(prepared: Self.prepared(4), credit: .submitter)), .kept(id: "second")],
                base: ["cover", "second"],
            ),
        )

        form.removePhoto(second)
        form.removePhoto(added.id)
        expectNoDifference(
            try #require(form.suggestion()).photoEdit,
            SpotEditSuggestion.PhotoEdit(order: [], base: ["cover", "second"]),
        )
    }

    @Test
    func `an edit that didn't load the spot's photos adds new ones after them`() throws {
        var target = Self.wellLedges
        target.photos = nil
        var form = NewSpotForm(editing: target)
        expectNoDifference(form.photos.count, 0)
        expectNoDifference(form.missing, [.change])

        form.append(Self.readyPhoto(5))
        let suggestion = try #require(form.suggestion())
        expectNoDifference(suggestion.changedFields, [.photos])
        expectNoDifference(
            suggestion.photoEdit,
            .adding([NewSpot.Photo(prepared: Self.prepared(5), credit: .submitter)]),
        )
        expectNoDifference(suggestion.photoEdit?.base, nil)
    }

    @Test
    func `the spot's own photos take no credit and can't fail`() {
        var form = NewSpotForm(editing: Self.wellLedges)
        let cover = form.photos[0].id

        form.updateAddedPhoto(cover) { $0.state = .failed }
        form.updateAddedPhoto(cover) { $0.credit.takenBySubmitter = false }
        expectNoDifference(form.photos.map(\.stored?.id), Self.wellLedgesPhotos.map(\.id))
        expectNoDifference(form.missing, [.change])
    }

    @Test
    func `an edit with a photo still preparing waits for it`() {
        var form = NewSpotForm(editing: Self.wellLedges)
        form.append(NewSpotForm.Photo())

        expectNoDifference(form.missing, [.photosReady])
        #expect(form.suggestion() == nil)
    }

    @Test
    func `review starts as a new spot's card proposes, takes no photos, and approves it as it is`() {
        let form = NewSpotForm(reviewing: Self.newSpotCard)

        expectNoDifference(form.title, "Vauxhall DIY Bowl")
        expectNoDifference(form.about, "A concrete bowl under the railway.")
        expectNoDifference(form.kind, .diy)
        expectNoDifference(form.obstacles, ["bowl", "quarter pipe"])
        expectNoDifference(form.location?.coordinate.latitude, 51.486)
        expectNoDifference(form.photos.map(\.stored?.id), Self.newSpotCard.photos.map(\.id))
        #expect(SpotEditField.allCases.allSatisfy(form.isEditable))
        #expect(!form.canAddPhotos)
        #expect(form.missing.isEmpty)
        #expect(!form.hasChanges)
        expectNoDifference(form.approval(), SpotEdits.none)
        #expect(form.spot() == nil)
        #expect(form.suggestion() == nil)
    }

    @Test
    func `a suggested edit's card lets the curator change only what it suggests`() {
        let form = NewSpotForm(reviewing: Self.editCard(changing: [.condition, .photos]))

        expectNoDifference(SpotEditField.allCases.filter(form.isEditable), [.condition, .photos])
        #expect(NewSpotForm().isEditable(.title))
        #expect(NewSpotForm(editing: Self.wellLedges).isEditable(.title))
    }

    @Test
    func `approving sends only what the curator changed, the photos to publish in order`() {
        var form = NewSpotForm(reviewing: Self.newSpotCard)
        form.about = " A concrete bowl and a quarter pipe under the railway. "
        form.location = NewSpotForm.Location(
            coordinate: CLLocationCoordinate2D(latitude: 51.4861, longitude: -0.124),
            name: "Vauxhall",
        )
        form.removePhoto(form.photos[0].id)
        form.makeCover(form.photos[1].id)

        #expect(form.hasChanges)
        expectNoDifference(
            form.approval(),
            SpotEdits(
                about: "A concrete bowl and a quarter pipe under the railway.",
                coordinate: SpotEdits.Coordinate(latitude: 51.4861, longitude: -0.124),
                photoIDs: ["p2", "p1"],
            ),
        )
    }

    @Test
    func `the card's obstacles in their own order aren't a change; a new set goes out in chip order`() {
        var form = NewSpotForm(reviewing: Self.newSpotCard)
        form.obstacles = ["bowl", "quarter pipe"]
        expectNoDifference(form.approval(), SpotEdits.none)

        form.obstacles.insert("ledges")
        expectNoDifference(form.approval(), SpotEdits(obstacles: ["ledges", "bowl", "quarter pipe"]))
    }

    @Test
    func `a cleared name holds Approve back and is worth confirming before it's thrown away`() {
        var form = NewSpotForm(reviewing: Self.newSpotCard)
        form.title = "  "

        expectNoDifference(form.missing, [.name])
        #expect(form.approval() == nil)
        #expect(form.hasChanges)
    }

    @Test
    func `an empty form asks for a name, the location and the kind, and has nothing to lose`() {
        let form = NewSpotForm()

        expectNoDifference(form.missing, [.name, .location, .kind])
        #expect(!form.canSubmit)
        #expect(!form.hasChanges)
        #expect(form.spot() == nil)
    }

    @Test
    func `a complete form can be submitted`() {
        #expect(Self.complete().canSubmit)
        #expect(Self.complete().missing.isEmpty)
    }

    @Test
    func `an edit adds up to ten new photos, whatever the spot already has`() {
        var form = NewSpotForm(editing: Self.wellLedges)
        #expect(form.photosLeft == 10)
        for tag in 0..<10 {
            form.append(Self.readyPhoto(UInt8(tag)))
        }
        #expect(form.photos.count == 12)
        #expect(!form.canAddPhotos)
    }

    @Test
    func `a spot can be submitted without a photo`() throws {
        var form = Self.complete()
        form.removePhoto(form.photos[0].id)

        #expect(form.canSubmit)
        expectNoDifference(try #require(form.spot()).photos, [])
        expectNoDifference(form.coverThumbhash, nil)
    }

    @Test
    func `a name of only spaces is no name, and isn't a change worth confirming`() {
        var form = NewSpotForm()
        form.title = "   "
        #expect(form.missing.contains(.name))
        #expect(!form.hasChanges)

        var complete = Self.complete()
        complete.title = String(repeating: "a", count: 121)
        #expect(complete.missing == [.name])
    }

    @Test
    func `a photo still being prepared, or one that couldn't be read, holds Submit back`() {
        var form = Self.complete()
        let preparing = NewSpotForm.Photo()
        form.append(preparing)
        #expect(form.missing == [.photosReady])

        form.updateAddedPhoto(preparing.id) { $0.state = .failed }
        #expect(form.missing == [.photosReady])

        form.removePhoto(preparing.id)
        #expect(form.canSubmit)
    }

    @Test
    func `someone else's photo needs their name and the permission switch`() {
        var form = Self.complete()
        let id = form.photos[0].id
        form.updateAddedPhoto(id) { $0.credit.takenBySubmitter = false }
        #expect(form.missing == [.photoCredits])

        form.updateAddedPhoto(id) { $0.credit.name = "   " }
        form.updateAddedPhoto(id) { $0.credit.hasPermission = true }
        #expect(form.missing == [.photoCredits])

        form.updateAddedPhoto(id) { $0.credit.name = "@londonlens" }
        form.updateAddedPhoto(id) { $0.credit.hasPermission = false }
        #expect(form.missing == [.photoCredits])

        form.updateAddedPhoto(id) { $0.credit.hasPermission = true }
        #expect(form.canSubmit)
    }

    @Test
    func `the draft is the same NewSpot the outbox always took, trimmed and in chip order`() {
        var form = Self.complete()
        form.title = "  Southbank Undercroft "
        form.about = "\nThe birthplace of British street skating. "
        form.note = " Busy on weekends "
        form.condition = .knobbed
        form.obstacles = ["stairs", "banks", "ledges"]
        form.append(Self.readyPhoto(
            2,
            credit: NewSpotForm.Credit(takenBySubmitter: false, name: " @londonlens ", hasPermission: true),
        ))

        expectNoDifference(
            form.spot(),
            NewSpot(
                title: "Southbank Undercroft",
                about: "The birthplace of British street skating.",
                kind: .plaza,
                obstacles: ["ledges", "stairs", "banks"],
                condition: .knobbed,
                latitude: 51.5066,
                longitude: -0.1169,
                note: "Busy on weekends",
                photos: [
                    NewSpot.Photo(prepared: Self.prepared(1), credit: .submitter),
                    NewSpot.Photo(prepared: Self.prepared(2), credit: .someoneElse(name: "@londonlens", sourceURL: nil)),
                ],
            ),
        )
    }

    @Test
    func `a photo with a clip goes out with its clip, in a new spot and in an edit`() throws {
        let clip = PreparedClip(
            file: URL.temporaryDirectory.appending(path: "clip.mp4"),
            width: 720,
            height: 1280,
            durationMs: 12400,
            bytes: 2_000_000,
        )
        let clipPhoto = NewSpotForm.Photo(NewSpotForm.Photo.Added(state: .ready(Self.prepared(2)), clip: clip))

        var form = Self.complete()
        form.append(clipPhoto)
        expectNoDifference(form.photos.map(\.clipMilliseconds), [nil, 12400])
        expectNoDifference(
            try #require(form.spot()).photos,
            [
                NewSpot.Photo(prepared: Self.prepared(1), credit: .submitter),
                NewSpot.Photo(prepared: Self.prepared(2), credit: .submitter, clip: clip),
            ],
        )

        var edit = NewSpotForm(editing: Self.wellLedges)
        edit.append(clipPhoto)
        edit.makeCover(clipPhoto.id)
        expectNoDifference(
            try #require(edit.suggestion()).photoEdit?.order,
            [
                .added(NewSpot.Photo(prepared: Self.prepared(2), credit: .submitter, clip: clip)),
                .kept(id: "cover"),
                .kept(id: "second"),
            ],
        )
    }

    @Test
    func `a stored photo's clip shows how long it runs`() {
        var spot = Self.wellLedges
        spot.photos?[1].clip = SpotClip(key: "clips/b.mp4", width: 720, height: 1280, durationMs: 9000)
        var card = Self.newSpotCard
        card.photos[0].clip = SpotClip(key: "clips/p0.mp4", width: 720, height: 1280, durationMs: 4000)

        expectNoDifference(NewSpotForm(editing: spot).photos.map(\.clipMilliseconds), [nil, 9000])
        expectNoDifference(NewSpotForm(reviewing: card).photos.map(\.clipMilliseconds), [4000, nil, nil])
    }

    @Test
    func `the cover is the first photo, and making another the cover moves it to the front`() {
        var form = Self.complete()
        let second = Self.readyPhoto(2)
        form.append(second)
        form.makeCover(second.id)

        #expect(form.photos.map(\.id).first == second.id)
        #expect(form.coverThumbhash == Self.prepared(2).thumbhash)
    }

    @Test
    func `a photo moves to the place it's dropped at, and the spot keeps that order`() {
        var form = Self.complete()
        let cover = form.photos[0].id
        let second = Self.readyPhoto(2)
        let third = Self.readyPhoto(3)
        form.append(second)
        form.append(third)

        form.movePhoto(third.id, to: 1)
        #expect(form.photos.map(\.id) == [cover, third.id, second.id])

        form.movePhoto(cover, to: 99)
        #expect(form.photos.map(\.id) == [third.id, second.id, cover])
        #expect(form.spot()?.photos.map(\.prepared) == [Self.prepared(3), Self.prepared(2), Self.prepared(1)])
    }

    @Test
    func `there's room for ten photos and no more`() {
        var form = NewSpotForm()
        for tag in 0..<10 {
            let added = form.append(Self.readyPhoto(UInt8(tag)))
            #expect(added)
        }
        let eleventh = form.append(Self.readyPhoto(10))

        #expect(!form.canAddPhotos)
        #expect(!eleventh)
        #expect(form.photos.count == 10)
    }

    @Test
    func `anything entered is worth confirming before it's thrown away; blank text isn't`() {
        var form = NewSpotForm()
        form.note = "  \n"
        form.about = " "
        #expect(!form.hasChanges)

        form.condition = .busty
        #expect(form.hasChanges)

        var located = NewSpotForm()
        located.location = Self.complete().location
        #expect(located.hasChanges)

        var kinded = NewSpotForm()
        kinded.kind = .diy
        #expect(kinded.hasChanges)
    }

    @Test
    func `an address reads as the place's name and a second line`() {
        let point = CLLocationCoordinate2D(latitude: 51.5066, longitude: -0.1169)

        expectNoDifference(
            LocationSearchViewController.place(at: point, address: "Belvedere Road, London SE1 8XX", fallback: "Dropped Pin"),
            NewSpotForm.Location(coordinate: point, name: "Belvedere Road", subtitle: "London SE1 8XX"),
        )
        expectNoDifference(
            LocationSearchViewController.place(at: point, address: nil, fallback: "Dropped Pin"),
            NewSpotForm.Location(coordinate: point, name: "Dropped Pin"),
        )
    }

    @Test
    func `the dim ✓ tells VoiceOver what's still missing`() {
        #expect(NewSpotViewController.missingHint([]) == nil)
        #expect(NewSpotViewController.missingHint([.name, .kind]) == "To submit, add a name and the kind of spot")
        #expect(
            NewSpotViewController.missingHint([.photosReady, .name])
                == "To submit, add a name\nWait for the photos to load, or remove the ones that can't be read"
        )
    }
}
