import Foundation

/// Answers a URLSession's requests through `StubClipProtocol`: each test gets a host of its own, says how each path
/// answers, and hears what reached it in `events`.
actor StubClipServer {

    // MARK: Types

    enum Answer: Sendable {
        case clip(Data)
        case status(Int)
        /// Part of the clip, then the connection drops.
        case dropped(Data)
        /// The clip once `release(_:)` is called; until then the request waits.
        case held(Data)
    }

    enum Event: Equatable, Sendable {
        /// `limited`: the request may use neither expensive nor constrained networks.
        case started(path: String, limited: Bool)
        case stopped(path: String)
    }

    // MARK: Static Properties

    private static let servers = Servers()

    // MARK: Properties

    nonisolated let host = "\(UUID().uuidString.lowercased()).clips.test"
    nonisolated let events: AsyncStream<Event>

    private nonisolated let reports: AsyncStream<Event>.Continuation
    private var answers = [String: Answer]()
    private var held = [String: (loader: StubClipProtocol.Handle, clip: Data)]()

    // MARK: Computed Properties

    nonisolated var session: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubClipProtocol.self]
        return URLSession(configuration: configuration)
    }

    // MARK: Lifecycle

    private init() {
        (events, reports) = AsyncStream.makeStream()
    }

    // MARK: Static Functions

    static func make() async -> StubClipServer {
        let server = StubClipServer()
        await servers.add(server)
        return server
    }

    static func serving(_ host: String?) async -> StubClipServer? {
        await servers.server(for: host)
    }

    // MARK: Functions

    nonisolated func url(_ path: String) -> URL {
        URL(string: "https://\(host)/\(path)")!
    }

    func answer(_ path: String, with answer: Answer) {
        answers[path] = answer
    }

    func release(_ path: String) {
        guard let waiting = held.removeValue(forKey: path) else {
            return
        }
        waiting.loader.protocol.respond(status: 200, body: waiting.clip)
    }

    /// Ends `events`, once everything a test waits for has happened.
    func finishEvents() {
        reports.finish()
    }

    func start(_ handle: StubClipProtocol.Handle) {
        let loader = handle.protocol
        let request = loader.request
        let path = String(request.url?.path().dropFirst() ?? "")
        reports.yield(.started(
            path: path,
            limited: !request.allowsExpensiveNetworkAccess && !request.allowsConstrainedNetworkAccess,
        ))
        switch answers[path] {
        case .clip(let clip): loader.respond(status: 200, body: clip)
        case .status(let status): loader.respond(status: status, body: Data())
        case .dropped(let part): loader.respond(status: 200, body: part, dropping: true)
        case .held(let clip): held[path] = (handle, clip)
        case nil: loader.respond(status: 404, body: Data())
        }
    }

    func stopped(_ path: String) {
        reports.yield(.stopped(path: path))
    }
}

// MARK: - Servers

private actor Servers {

    // MARK: Properties

    private var servers = [String: StubClipServer]()

    // MARK: Functions

    func add(_ server: StubClipServer) {
        servers[server.host] = server
    }

    func server(for host: String?) -> StubClipServer? {
        host.flatMap { servers[$0] }
    }
}

// MARK: - StubClipProtocol

/// URLSession makes one per request and hands it to the server, which answers through its client once.
final class StubClipProtocol: URLProtocol {

    // MARK: Types

    /// Foundation keeps URLProtocol non-Sendable; only the server touches a loader after `startLoading`.
    struct Handle: @unchecked Sendable {
        let `protocol`: StubClipProtocol
    }

    // MARK: Overridden Functions

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    // MARK: Overrides

    override func startLoading() {
        let handle = Handle(protocol: self)
        let host = request.url?.host()
        Task {
            await StubClipServer.serving(host)?.start(handle)
        }
    }

    override func stopLoading() {
        let url = request.url
        Task {
            await StubClipServer.serving(url?.host())?.stopped(String(url?.path().dropFirst() ?? ""))
        }
    }

    // MARK: Functions

    func respond(status: Int, body: Data, dropping: Bool = false) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: status,
                  httpVersion: "HTTP/1.1",
                  headerFields: ["Content-Length": "\(dropping ? body.count * 2 : body.count)"],
              ) else {
            return
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        if dropping {
            client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost))
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
