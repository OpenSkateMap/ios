import Foundation
import HTTPTypes
public import OpenAPIRuntime

extension SessionCredentials {
    public func authorized<Output>(_ makeClient: ([any ClientMiddleware]) -> Client,
                                   signedOut: @autoclosure () -> any Error,
                                   offline: @autoclosure () -> any Error,
                                   failure: (APIFailure) -> any Error,
                                   _ call: (Client) async throws -> Output) async throws -> Output {
        guard let token = await token() else {
            throw signedOut()
        }
        var middlewares: [any ClientMiddleware] = [
            BearerTokenMiddleware(token: token),
            RefusedTokenMiddleware(token: token, refused: refused),
        ]
        if doNotTrack() {
            middlewares.append(DoNotTrackMiddleware())
        }
        let client = makeClient(middlewares)
        return try await withAPIFailures(offline: offline(), failure) {
            try await call(client)
        }
    }
}

/// The caller's errors for what went wrong on the way: an answer outside 2xx through `failure`, a transport failure as
/// `offline`. Cancellation stays cancellation; contract mismatches (decoding `ClientError`s, bugs) pass through.
public func withAPIFailures<Output>(offline: @autoclosure () -> any Error,
                                    _ failure: (APIFailure) -> any Error,
                                    _ call: () async throws -> Output) async throws -> Output {
    do {
        return try await call()
    } catch let error as ClientError {
        switch error.underlyingError {
        case let answer as APIFailure: throw failure(answer)
        case let transport as URLError: throw transport.code == .cancelled ? CancellationError() : offline()
        default: throw error
        }
    }
}

// MARK: - RefusedTokenMiddleware

private struct RefusedTokenMiddleware: ClientMiddleware {
    let token: String
    let refused: @Sendable (_ token: String) async -> Void

    func intercept(_ request: HTTPRequest,
                   body: HTTPBody?,
                   baseURL: URL,
                   operationID _: String,
                   next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?))
        async throws -> (HTTPResponse, HTTPBody?) {
        let (response, responseBody) = try await next(request, body, baseURL)
        if response.status == .unauthorized {
            await refused(token)
        }
        return (response, responseBody)
    }
}

// MARK: - DoNotTrackMiddleware

private struct DoNotTrackMiddleware: ClientMiddleware {
    func intercept(_ request: HTTPRequest,
                   body: HTTPBody?,
                   baseURL: URL,
                   operationID _: String,
                   next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?))
        async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[HTTPField.Name("DNT")!] = "1"
        return try await next(request, body, baseURL)
    }
}
