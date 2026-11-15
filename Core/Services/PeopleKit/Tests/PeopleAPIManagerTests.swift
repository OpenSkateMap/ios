import APIClientKit
import CustomDump
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Synchronization
import Testing
@testable import PeopleKit

// MARK: - PeopleAPIManagerTests

@Suite(.timeLimit(.minutes(1)))
struct PeopleAPIManagerTests {
    private static let profileJSON = """
        {"ok":true,"data":{"id":"u1","name":"Rider","username":"rider","bio":"Ledges.","avatar":{"key":"photos/a.jpg",\
        "thumbhash":"1QcS"},"handles":{"instagram":"rider_ig","tiktok":null,"youtube":null,"x":null,"telegram":null,\
        "website":"https://rider.example"},"role":"editor","editorOf":[{"id":"london","name":"London"}],\
        "stats":{"submitted":3,"approved":2,"cities":1},"joinedAt":"2026-10-09T18:20:00.000Z","blockedByMe":false}}
        """

    private static func error(_ code: String, _ message: String) -> String {
        #"{"ok":false,"error":{"code":"\#(code)","message":"\#(message)","retryable":false}}"#
    }

    @Test
    func `a profile decodes with its handles, role and cities`() async throws {
        let api = PeopleAPIManager.live(credentials: .constant("token")) {
            Client.production(transport: StubTransport(status: .ok, json: Self.profileJSON), middlewares: $0)
        }

        let profile = try await api.profile("u1")

        expectNoDifference(profile.handles, Handles([.instagram: "rider_ig", .website: "https://rider.example"]))
        expectNoDifference(profile.role, .editor)
        expectNoDifference(profile.editorOf, [.init(id: "london", name: "London")])
        expectNoDifference(profile.stats, .init(submitted: 3, approved: 2, cities: 1))
        expectNoDifference(profile.avatar, .init(key: "photos/a.jpg", thumbhash: "1QcS"))
    }

    @Test
    func `an update sends only what changed, and emptied fields as a clear list`() async throws {
        let sent = Mutex([String]())
        let api = PeopleAPIManager.live(credentials: .constant("token")) {
            Client.production(transport: StubTransport(status: .ok, json: Self.profileJSON) { request, body in
                sent.withLock { $0.append("\(request.method) \(request.path ?? "") \(body)") }
            }, middlewares: $0)
        }

        _ = try await api.updateMyProfile(ProfileUpdate(
            username: "rider_two",
            avatar: .init(photoID: "p1", thumbhash: "1QcS"),
            handles: [.x: "rider_x"],
            clear: [.bio, .instagram],
        ))

        expectNoDifference(sent.withLock { $0 }, [
            #"PATCH /v1/me/profile {"avatar":{"photoId":"p1","thumbhash":"1QcS"},"clear":["bio","instagram"],"handles":{"x":"rider_x"},"username":"rider_two"}"#
        ])
    }

    @Test
    func `a report carries the target, the reason and a trimmed note`() async throws {
        let sent = Mutex([String]())
        let api = PeopleAPIManager.live(credentials: .constant("token")) {
            Client.production(transport: StubTransport(status: .ok, json: #"{"ok":true,"data":{"id":"r1"}}"#) { request, body in
                sent.withLock { $0.append("\(request.method) \(request.path ?? "") \(body)") }
            }, middlewares: $0)
        }

        try await api.report(Report(target: .spot(id: "s1"), reason: .privateProperty, message: "  Backyard pool \n"))
        try await api.report(Report(target: .user(id: "u2"), reason: .harassment))

        expectNoDifference(sent.withLock { $0 }, [
            #"POST /v1/reports {"message":"Backyard pool","reason":"private_property","targetId":"s1","targetKind":"spot"}"#,
            #"POST /v1/reports {"reason":"harassment","targetId":"u2","targetKind":"user"}"#,
        ])
    }

    @Test
    func `a taken username and an unavailable profile come back as their own errors`() async throws {
        let taken = PeopleAPIManager.live(credentials: .constant("token")) {
            Client.production(
                transport: StubTransport(status: .conflict, json: Self.error("conflict", "That username is taken")),
                middlewares: $0,
            )
        }
        let gone = PeopleAPIManager.live(credentials: .constant("token")) {
            Client.production(
                transport: StubTransport(status: .notFound, json: Self.error("not_found", "No such person")),
                middlewares: $0,
            )
        }

        await #expect(throws: PeopleAPIError.usernameUnavailable) {
            try await taken.updateMyProfile(ProfileUpdate(username: "taken"))
        }
        await #expect(throws: PeopleAPIError.notFound) {
            try await gone.profile("u9")
        }
    }

    @Test
    func `a conflict anywhere but a profile save is the server's refusal`() async throws {
        let api = PeopleAPIManager.live(credentials: .constant("token")) {
            Client.production(
                transport: StubTransport(status: .conflict, json: Self.error("conflict", "Already blocked")),
                middlewares: $0,
            )
        }

        await #expect(throws: PeopleAPIError.rejected("Already blocked")) {
            try await api.setBlocked("u2", true)
        }
    }

    @Test
    func `a refused token is reported once and signs the call out`() async throws {
        let refused = Mutex([String]())
        let credentials = SessionCredentials(token: { "stale" }, refused: { token in refused.withLock { $0.append(token) } })
        let api = PeopleAPIManager.live(credentials: credentials) {
            Client.production(
                transport: StubTransport(status: .unauthorized, json: Self.error("auth_required", "Sign in")),
                middlewares: $0,
            )
        }

        await #expect(throws: PeopleAPIError.unauthorized) {
            try await api.blockedUsers()
        }
        expectNoDifference(refused.withLock { $0 }, ["stale"])
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
