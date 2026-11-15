import APIClientKit
import CustomDump
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import AccountKit

// MARK: - AuthAPIManagerTests

@Suite(.timeLimit(.minutes(1)))
struct AuthAPIManagerTests {
    @Test
    func `sign-in sends the raw nonce and decodes the session`() async throws {
        let sent = Calls()
        let api = AuthAPIManager.live { middlewares in
            Client.production(transport: StubTransport(status: .ok, json: """
                {"ok":true,"data":{"token":"session-token","user":{"id":"user-1","name":"Test Skater",\
                "email":"skater@privaterelay.appleid.com","role":"editor","createdAt":"2026-10-09T12:30:45.123Z"}}}
                """) { request, body in
                sent.record("\(request.method) \(request.path ?? "") auth=\(request.headerFields[.authorization] ?? "none")")
                sent.record(body)
            }, middlewares: middlewares)
        }

        let session = try await api.signInWithApple(AppleCredential(
            userID: "apple-user-1",
            identityToken: "apple-identity-token",
            rawNonce: "raw-nonce-0123456789",
            authorizationCode: "apple-authorization-code",
            givenName: "Test",
            familyName: "",
        ))

        expectNoDifference(session.token, "session-token")
        expectNoDifference(session.account.role, .editor)
        expectNoDifference((session.account.createdAt.timeIntervalSince1970 * 1000).rounded(), 1_791_549_045_123)
        expectNoDifference(sent.values, [
            "POST /v1/auth/apple auth=none",
            #"{"authorizationCode":"apple-authorization-code","givenName":"Test","idToken":"apple-identity-token","nonce":"raw-nonce-0123456789"}"#,
        ])
    }

    @Test
    func `account calls carry the session token as a bearer header`() async throws {
        let sent = Calls()
        let api = AuthAPIManager.live { middlewares in
            Client.production(transport: StubTransport(status: .ok, json: #"{"ok":true,"data":{"deleted":true}}"#) { request, _ in
                sent.record("\(request.method) \(request.path ?? "") auth=\(request.headerFields[.authorization] ?? "none")")
            }, middlewares: middlewares)
        }

        try await api.deleteAccount("session-token")

        expectNoDifference(sent.values, ["DELETE /v1/me auth=Bearer session-token"])
    }

    @Test
    func `a 401 envelope becomes unauthorized`() async {
        let api = AuthAPIManager.live { middlewares in
            Client.production(transport: StubTransport(status: .unauthorized, json: """
                {"ok":false,"error":{"code":"auth_required","message":"Sign in to continue","retryable":false}}
                """), middlewares: middlewares)
        }

        await #expect(throws: AuthAPIError.unauthorized) {
            _ = try await api.me("expired-token")
        }
    }

    @Test
    func `no connection becomes offline`() async {
        let api = AuthAPIManager.live { middlewares in
            Client.production(transport: FailingTransport(error: URLError(.notConnectedToInternet)), middlewares: middlewares)
        }

        await #expect(throws: AuthAPIError.offline) {
            _ = try await api.me("session-token")
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

// MARK: - FailingTransport

private struct FailingTransport: ClientTransport {
    let error: URLError

    func send(_: HTTPRequest, body _: HTTPBody?, baseURL _: URL, operationID _: String) async throws
        -> (HTTPResponse, HTTPBody?) {
        throw error
    }
}
