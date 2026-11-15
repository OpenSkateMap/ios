import APIClientKit
import CustomDump
import Foundation
import HTTPTypes
import OpenAPIRuntime
import SpotModelKit
import Synchronization
import Testing
@testable import ReviewKit

// MARK: - ReviewAPIManagerTests

@Suite(.timeLimit(.minutes(1)))
struct ReviewAPIManagerTests {
    private static let queueJSON = """
        {"ok":true,"data":{"cityIds":["london"],"items":[{"id":"sub-1","kind":"new_spot","status":"pending",\
        "title":"Ledges","description":"","spotKind":"street","obstacles":["ledges"],"condition":"skateable",\
        "latitude":51.5066,"longitude":-0.1169,"cityId":"london","note":"Busy on weekends","photos":[\
        {"photoId":"p1","key":"photos/b.jpg","width":480,"height":640,"thumbhash":"2QcS","credit":\
        {"takenBy":"someone_else","credit":"@lens","hasPermission":true},"position":1,"existing":false},\
        {"photoId":"p0","key":"photos/a.jpg","width":640,"height":480,"thumbhash":"1QcS","credit":\
        {"takenBy":"submitter"},"position":0,"existing":false}],"spotId":null,"changedFields":[],\
        "rejectReason":null,\
        "createdAt":"2026-10-09T18:20:00.000Z","updatedAt":"2026-10-09T18:26:02.273Z",\
        "submitter":{"id":"u1","name":"Rider"},"reviewAs":"curator","current":null,"nearby":[{"id":"s1","title":"Southbank","kind":"plaza",\
        "latitude":51.5066,"longitude":-0.1169,"distanceMeters":3}]}],"videos":[{"id":"vid-1","spotId":"s1",\
        "provider":"youtube","externalId":"dQw4w9WgXcQ","url":"https://www.youtube.com/watch?v=dQw4w9WgXcQ",\
        "startSeconds":null,"thumbnailUrl":"https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg","caption":"Kickflip",\
        "createdAt":"2026-10-09T18:21:00.000Z","status":"pending","rejectReason":null,\
        "updatedAt":"2026-10-09T18:21:00.000Z","spot":{"id":"s1","title":"Southbank","kind":"plaza",\
        "cityId":"london"},"submitter":{"id":"u2","name":"Filmer"},"reviewAs":"curator"}]}}
        """

    private static let decidedJSON = """
        {"ok":true,"data":{"id":"sub-1","kind":"new_spot","status":"approved","title":"Undercroft",\
        "description":"","spotKind":"street","obstacles":["ledges"],"condition":"skateable","latitude":51.5066,\
        "longitude":-0.1169,"cityId":"london","note":"","photos":[],"spotId":"spot-9","changedFields":[],\
        "rejectReason":null,"createdAt":"2026-10-09T18:20:00.000Z","updatedAt":"2026-10-09T18:30:00.500Z"}}
        """

    private static let editQueueJSON = """
        {"ok":true,"data":{"cityIds":["london"],"items":[{"id":"sub-2","kind":"edit_spot","status":"pending",\
        "title":"Well Ledges","description":"Marble ledges","spotKind":"plaza","obstacles":["ledges"],\
        "condition":"knobbed","latitude":51.5066,"longitude":-0.1169,"cityId":"london","note":"","photos":[\
        {"photoId":"n1","key":"photos/n.jpg","width":640,"height":480,"thumbhash":"3QcS","credit":{"takenBy":"submitter"},\
        "position":0,"existing":false},{"photoId":"s2","key":"photos/s.jpg","width":640,"height":480,"thumbhash":"4QcS",\
        "credit":{"takenBy":"submitter"},"position":1,"existing":true}],\
        "spotId":"spot-1","changedFields":["condition","photos"],"rejectReason":null,\
        "createdAt":"2026-10-10T18:20:00.000Z","updatedAt":"2026-10-10T18:20:00.000Z",\
        "submitter":{"id":"u1","name":"Rider"},"reviewAs":"curator","nearby":[],"current":{"title":"Well Ledges",\
        "description":"Marble ledges","spotKind":"plaza","obstacles":["ledges"],"condition":"skateable",\
        "latitude":51.5066,"longitude":-0.1169,"photoCount":2,"removedPhotoCount":1}}],"videos":[]}}
        """

    private static func error(_ code: String, _ message: String) -> String {
        #"{"ok":false,"error":{"code":"\#(code)","message":"\#(message)","retryable":false}}"#
    }

    @Test
    func `the queue decodes into cards with photos in order and credits, and pending videos`() async throws {
        let api = ReviewAPIManager.live(credentials: .constant("token")) {
            Client.production(transport: StubTransport(status: .ok, json: Self.queueJSON), middlewares: $0)
        }

        let queue = try await api.queue(nil, 50)

        let card = try #require(queue.cards.first)
        expectNoDifference(queue.cityIDs, ["london"])
        expectNoDifference(card.photos.map(\.id), ["p0", "p1"])
        expectNoDifference(card.photos.map(\.credit), [.submitter, .someoneElse(name: "@lens", sourceURL: nil)])
        expectNoDifference(card.submitterName, "Rider")
        expectNoDifference(card.nearby.map(\.distanceMeters), [3])
        let video = try #require(queue.videos.first)
        expectNoDifference(video.spotTitle, "Southbank")
        expectNoDifference(video.provider, .youtube)
        expectNoDifference(video.url, URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"))
        expectNoDifference(video.submitterName, "Filmer")
    }

    @Test
    func `an edit's card carries what it changes and the spot as it is now`() async throws {
        let api = ReviewAPIManager.live(credentials: .constant("token")) {
            Client.production(transport: StubTransport(status: .ok, json: Self.editQueueJSON), middlewares: $0)
        }

        let card = try #require(try await api.queue(nil, 50).cards.first)

        #expect(card.isEdit)
        expectNoDifference(card.spotID, "spot-1")
        expectNoDifference(card.changedFields, [.condition, .photos])
        expectNoDifference(card.photos.map(\.attribution), [.submitter, .spot])
        expectNoDifference(card.condition, .knobbed)
        expectNoDifference(card.current?.condition, .skateable)
        expectNoDifference(card.current?.photoCount, 2)
        expectNoDifference(card.current?.removedPhotoCount, 1)
    }

    @Test
    func `an approval sends back the exact timestamp the card came with, and only the edits`() async throws {
        let sent = Mutex([String]())
        let queueAPI = ReviewAPIManager.live(credentials: .constant("token")) {
            Client.production(transport: StubTransport(status: .ok, json: Self.queueJSON), middlewares: $0)
        }
        let card = try #require(try await queueAPI.queue(nil, 50).cards.first)
        let api = ReviewAPIManager.live(credentials: .constant("token")) {
            Client.production(transport: StubTransport(status: .ok, json: Self.decidedJSON) { request, body in
                sent.withLock { $0.append("\(request.method) \(request.path ?? "") \(body)") }
            }, middlewares: $0)
        }

        let decided = try await api.approve(card.id, SpotEdits(title: "Undercroft"), card.updatedAt)

        expectNoDifference(decided.spotID, "spot-9")
        expectNoDifference(sent.withLock { $0 }, [
            #"POST /v1/review/sub-1/approve {"edits":{"title":"Undercroft"},"seenUpdatedAt":"2026-10-09T18:26:02.273Z","wholePhotoList":true}"#
        ])
    }

    @Test
    func `an approval as submitted sends no edits`() async throws {
        let sent = Mutex([String]())
        let api = ReviewAPIManager.live(credentials: .constant("token")) {
            Client.production(transport: StubTransport(status: .ok, json: Self.decidedJSON) { _, body in
                sent.withLock { $0.append(body) }
            }, middlewares: $0)
        }

        _ = try await api.approve("sub-1", .none, Date(timeIntervalSince1970: 1_791_590_400))

        expectNoDifference(sent.withLock { $0 }, [#"{"seenUpdatedAt":"2026-10-10T00:00:00.000Z","wholePhotoList":true}"#])
    }

    @Test
    func `a rejection sends the reason in the API's spelling`() async throws {
        let sent = Mutex([String]())
        let api = ReviewAPIManager.live(credentials: .constant("token")) {
            Client.production(transport: StubTransport(status: .ok, json: Self.decidedJSON) { _, body in
                sent.withLock { $0.append(body) }
            }, middlewares: $0)
        }

        _ = try await api.reject("sub-1", .privateProperty, Date(timeIntervalSince1970: 1_791_590_400))

        expectNoDifference(sent.withLock { $0 }, [#"{"reason":"private_property","seenUpdatedAt":"2026-10-10T00:00:00.000Z"}"#])
    }

    @Test
    func `a 409 is a conflict and a 403 is forbidden`() async {
        let conflict = ReviewAPIManager.live(credentials: .constant("token")) {
            Client.production(
                transport: StubTransport(status: .conflict, json: Self.error("conflict", "changed")),
                middlewares: $0,
            )
        }
        let forbidden = ReviewAPIManager.live(credentials: .constant("token")) {
            Client.production(
                transport: StubTransport(status: .forbidden, json: Self.error("forbidden", "not yours")),
                middlewares: $0,
            )
        }

        await #expect(throws: ReviewAPIError.conflict("changed")) {
            _ = try await conflict.approve("sub-1", .none, .now)
        }
        await #expect(throws: ReviewAPIError.forbidden("not yours")) {
            _ = try await forbidden.undo("sub-1")
        }
    }

}

// MARK: - StubTransport

private struct StubTransport: ClientTransport {
    let status: HTTPResponse.Status
    let json: String
    var inspect: @Sendable (HTTPRequest, String) -> Void = { _, _ in }

    /// The encoder writes keys in no fixed order; sorted, bodies compare by what they say.
    private static func sortingKeys(_ json: String) throws -> String {
        guard !json.isEmpty else {
            return json
        }
        let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
        let sorted = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
        return String(decoding: sorted, as: UTF8.self)
    }

    func send(_ request: HTTPRequest,
              body: HTTPBody?,
              baseURL _: URL,
              operationID _: String) async throws -> (HTTPResponse, HTTPBody?) {
        let sentBody: String =
            if let body {
                try await String(collecting: body, upTo: 1 << 16)
            } else {
                ""
            }
        inspect(request, try Self.sortingKeys(sentBody))
        return (HTTPResponse(status: status, headerFields: [.contentType: "application/json"]), HTTPBody(json))
    }

}
