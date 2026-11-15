import CustomDump
import Foundation
import HTTPTypes
import OpenAPIRuntime
import Synchronization
import Testing
@testable import APIClientKit

// MARK: - APIClientKitTests

@Suite(.timeLimit(.minutes(1)))
struct APIClientKitTests {
    @Test
    func `health decodes the success envelope into typed values`() async throws {
        let client = Client.production(transport: StubTransport(status: .ok, json: """
            {"ok":true,"data":{"status":"ok","database":"ok"}}
            """) { request, operationID in
            expectNoDifference(request.method, .get)
            expectNoDifference(request.path, "/v1/health")
            expectNoDifference(operationID, "getHealth")
        })

        let health = try await client.getHealth().ok.body.json

        expectNoDifference(health.data.status, .ok)
        expectNoDifference(health.data.database, .ok)
    }

    @Test
    func `an answer outside 2xx is thrown as an APIFailure carrying the server's envelope`() async throws {
        let client = Client.production(transport: StubTransport(status: .serviceUnavailable, json: """
            {"ok":false,"error":{"code":"unavailable","message":"The database is not answering","retryable":true}}
            """))

        await #expect(throws: CallError.failed(APIFailure(
            status: 503,
            error: .init(code: .unavailable, message: "The database is not answering", retryable: true),
        ))) {
            try await withAPIFailures(offline: CallError.offline, CallError.failed) { try await client.getHealth().ok }
        }
    }

    @Test
    func `an error answer that isn't the envelope still says its status`() async throws {
        let client = Client.production(transport: StubTransport(status: .badGateway, json: "<html>Bad gateway</html>"))

        await #expect(throws: CallError.failed(APIFailure(status: 502))) {
            try await withAPIFailures(offline: CallError.offline, CallError.failed) { try await client.getHealth().ok }
        }
    }

    @Test
    func `the server URL literal matches the one the OpenAPI document declares`() throws {
        expectNoDifference(URL.openSkateMapAPI, try Servers.Server1.url())
    }

    @Test
    func `a signed-in session's token goes out as a bearer header`() async throws {
        let sent = Recorder()
        let client = Client.production(
            transport: StubTransport(status: .ok, json: #"{"ok":true,"data":{"status":"ok","database":"ok"}}"#) { request, _ in
                sent.record(request.headerFields[.authorization])
            },
            middlewares: [BearerTokenMiddleware(token: "session-token")],
        )

        _ = try await client.getHealth()

        expectNoDifference(sent.values, ["Bearer session-token"])
    }

    @Test
    func `without a session the request goes out with no authorization header`() async throws {
        let sent = Recorder()
        let client = Client.production(
            transport: StubTransport(status: .ok, json: #"{"ok":true,"data":{"status":"ok","database":"ok"}}"#) { request, _ in
                sent.record(request.headerFields[.authorization])
            },
            middlewares: [],
        )

        _ = try await client.getHealth()

        expectNoDifference(sent.values, [nil])
    }

    @Test
    func `a 401 answer to an authorized call reports the token it went out with, then fails`() async throws {
        let refused = Recorder()
        let credentials = SessionCredentials(token: { "session-token" }, refused: { refused.record($0) })

        await #expect(throws: CallError.failed(APIFailure(
            status: 401,
            error: .init(code: .authRequired, message: "Sign in again", retryable: false),
        ))) {
            try await credentials.authorized(
                { Client.production(transport: StubTransport(
                    status: .unauthorized,
                    json: #"{"ok":false,"error":{"code":"auth_required","message":"Sign in again","retryable":false}}"#,
                ), middlewares: $0) },
                signedOut: CallError.signedOut,
                offline: CallError.offline,
                failure: CallError.failed,
            ) { try await $0.getHealth().ok }
        }

        expectNoDifference(refused.values, ["session-token"])
    }

    @Test
    func `an authorized call without a session throws before anything is sent`() async throws {
        let sent = Recorder()
        await #expect(throws: CallError.signedOut) {
            try await SessionCredentials.signedOut.authorized(
                { middlewares in
                    Client.production(
                        transport: StubTransport(status: .ok, json: "{}") { request, _ in
                            sent.record(request.headerFields[.authorization])
                        },
                        middlewares: middlewares,
                    )
                },
                signedOut: CallError.signedOut,
                offline: CallError.offline,
                failure: CallError.failed,
            ) { try await $0.getHealth() }
        }
        expectNoDifference(sent.values, [])
    }

    @Test
    func `authorized calls say DNT only while analytics is off`() async throws {
        let sent = Recorder()
        for isOff in [false, true] {
            let credentials = SessionCredentials(token: { "session-token" }, refused: { _ in }, doNotTrack: { isOff })
            _ = try await credentials.authorized(
                { middlewares in
                    Client.production(
                        transport: StubTransport(
                            status: .ok,
                            json: #"{"ok":true,"data":{"status":"ok","database":"ok"}}"#,
                        ) { request, _ in
                            sent.record(request.headerFields[HTTPField.Name("DNT")!])
                        },
                        middlewares: middlewares,
                    )
                },
                signedOut: CallError.signedOut,
                offline: CallError.offline,
                failure: CallError.failed,
            ) { try await $0.getHealth() }
        }
        expectNoDifference(sent.values, [nil, "1"])
    }
}

// MARK: - CallError

private enum CallError: Error, Equatable {
    case signedOut
    case offline
    case failed(APIFailure)
}

// MARK: - Recorder

private final class Recorder: Sendable {

    // MARK: Computed Properties

    var values: [String?] {
        storage.withLock { $0 }
    }

    // MARK: Properties

    private let storage = Mutex<[String?]>([])

    // MARK: Functions

    func record(_ value: String?) {
        storage.withLock { $0.append(value) }
    }
}

// MARK: - StubTransport

private struct StubTransport: ClientTransport {
    let status: HTTPResponse.Status
    let json: String
    var inspect: @Sendable (HTTPRequest, String) -> Void = { _, _ in }

    func send(_ request: HTTPRequest,
              body _: HTTPBody?,
              baseURL _: URL,
              operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        inspect(request, operationID)
        return (HTTPResponse(status: status, headerFields: [.contentType: "application/json"]), HTTPBody(json))
    }
}
