import Foundation
import HTTPTypes
import OpenAPIRuntime

// MARK: - APIFailure

/// An answer outside 2xx: its status and, when the body was the API's error envelope, what the server said.
public struct APIFailure: Error, Equatable, Sendable {
    public var message: String? {
        error?.message
    }

    public var status: Int
    public var error: Components.Schemas.ErrorEnvelope._ErrorPayload?

    public init(status: Int, error: Components.Schemas.ErrorEnvelope._ErrorPayload? = nil) {
        self.status = status
        self.error = error
    }
}

// MARK: - FailureEnvelopeMiddleware

/// Throws every answer outside 2xx as an `APIFailure`, so call sites read only `.ok`. It goes first, the outermost, so
/// the middlewares after it (the one that reports a refused token) still see the response.
struct FailureEnvelopeMiddleware: ClientMiddleware {
    private static let maxEnvelopeBytes = 64 * 1024

    func intercept(_ request: HTTPRequest,
                   body: HTTPBody?,
                   baseURL: URL,
                   operationID _: String,
                   next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?))
        async throws -> (HTTPResponse, HTTPBody?) {
        let (response, responseBody) = try await next(request, body, baseURL)
        guard response.status.kind != .successful else {
            return (response, responseBody)
        }
        var envelope: Components.Schemas.ErrorEnvelope?
        if let responseBody, let data = try? await Data(collecting: responseBody, upTo: Self.maxEnvelopeBytes) {
            envelope = try? JSONDecoder().decode(Components.Schemas.ErrorEnvelope.self, from: data)
        }
        throw APIFailure(status: response.status.code, error: envelope?.error)
    }
}
