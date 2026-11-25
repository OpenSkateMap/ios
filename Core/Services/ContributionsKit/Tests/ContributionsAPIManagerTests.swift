import APIClientKit
import Foundation
import HTTPTypes
import OpenAPIRuntime
import SpotModelKit
import Testing
@testable import ContributionsKit

// MARK: - ContributionsAPIManagerTests

@Suite(.timeLimit(.minutes(1)))
struct ContributionsAPIManagerTests {
    private static let draft = SubmissionDraft(
        id: "s1",
        title: "Ledge",
        about: "",
        kind: .street,
        obstacles: [],
        condition: .skateable,
        latitude: 51.5,
        longitude: -0.12,
        note: "",
        createdAt: Date(timeIntervalSince1970: 1_791_590_400),
    )

    private static func api(_ status: HTTPResponse.Status, _ json: String) -> ContributionsAPIManager {
        .live(credentials: .constant("token")) { Client.production(
            transport: StubTransport(status: status, json: json),
            middlewares: $0,
        ) }
    }

    @Test
    func `a submission naming photos the server hasn't got asks for them again`() async throws {
        let api = Self.api(.unprocessableContent, """
            {"ok":false,"error":{"code":"validation_failed","message":"Upload these photos first","retryable":false,\
            "details":{"missingPhotos":["p1","p2"]}}}
            """)

        await #expect(throws: ContributionsAPIError.missingPhotos(["p1", "p2"])) {
            try await api.save(Self.draft, [])
        }
    }

    @Test
    func `a submission naming clips the server hasn't got asks for them again`() async throws {
        let api = Self.api(.unprocessableContent, """
            {"ok":false,"error":{"code":"validation_failed","message":"Upload these clips first","retryable":false,\
            "details":{"missingClips":["c1"]}}}
            """)

        await #expect(throws: ContributionsAPIError.missingClips(["c1"])) {
            try await api.save(Self.draft, [])
        }
    }

    @Test
    func `any other refusal carries its status, and the server's words for the log`() async throws {
        let api = Self.api(
            .unprocessableContent,
            #"{"ok":false,"error":{"code":"validation_failed","message":"Pick a kind","retryable":false}}"#,
        )

        await #expect(throws: ContributionsAPIError.rejected(status: 422, message: "Pick a kind")) {
            try await api.save(Self.draft, [])
        }
    }
}

// MARK: - StubTransport

private struct StubTransport: ClientTransport {
    let status: HTTPResponse.Status
    let json: String

    func send(_: HTTPRequest,
              body _: HTTPBody?,
              baseURL _: URL,
              operationID _: String) async throws -> (HTTPResponse, HTTPBody?) {
        (HTTPResponse(status: status, headerFields: [.contentType: "application/json"]), HTTPBody(json))
    }
}
