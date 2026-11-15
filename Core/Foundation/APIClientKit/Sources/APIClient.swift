public import Foundation
public import OpenAPIRuntime
import OpenAPIURLSession

extension Client {
    public static func production(serverURL: URL = .openSkateMapAPI, middlewares: [any ClientMiddleware] = []) -> Client {
        production(serverURL: serverURL, transport: URLSessionTransport(), middlewares: middlewares)
    }

    public static func production(serverURL: URL = .openSkateMapAPI,
                                  transport: any ClientTransport,
                                  middlewares: [any ClientMiddleware] = []) -> Client {
        Client(
            serverURL: serverURL,
            configuration: .openSkateMapAPI,
            transport: transport,
            middlewares: [FailureEnvelopeMiddleware()] + middlewares,
        )
    }
}

extension Configuration {
    /// The server's `toISOString()` dates carry milliseconds, which the default transcoder rejects. Bodies go out compact,
    /// not sorted and pretty-printed as the runtime's default encodes them.
    static let openSkateMapAPI = Configuration(dateTranscoder: .iso8601WithFractionalSeconds, jsonEncodingOptions: [])
}

extension URL {
    public static let openSkateMapAPI = URL(string: "https://api.openskatemap.app")!
}
