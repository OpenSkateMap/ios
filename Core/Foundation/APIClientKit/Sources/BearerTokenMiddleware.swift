public import Foundation
public import HTTPTypes
public import OpenAPIRuntime

public struct BearerTokenMiddleware: ClientMiddleware {
    private let token: String

    public init(token: String) {
        self.token = token
    }

    public func intercept(_ request: HTTPRequest,
                          body: HTTPBody?,
                          baseURL: URL,
                          operationID _: String,
                          next: @concurrent @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?))
        async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(token)"
        return try await next(request, body, baseURL)
    }
}
