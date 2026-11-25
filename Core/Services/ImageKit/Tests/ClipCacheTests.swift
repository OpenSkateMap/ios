import CustomDump
import Foundation
import Testing
@testable import ImageKit

@Suite(.timeLimit(.minutes(1)))
struct ClipCacheTests {
    private let server: StubClipServer
    private let directory = URL.temporaryDirectory.appending(path: "Clips \(UUID().uuidString)", directoryHint: .isDirectory)
    private let clip = Data(repeating: 7, count: 100)
    private let owner = UUID()

    init() async {
        server = await StubClipServer.make()
    }

    @Test
    func `a clip downloads alongside its first play and plays from disk the next time`() async throws {
        await server.answer("a.mp4", with: .clip(clip))
        let cache = cache()
        let url = server.url("a.mp4")

        #expect(await cache.beginPlaying(url) == nil)
        await cache.idle()
        let file = try #require(await cache.beginPlaying(url))

        let requests = await startedRequests()
        expectNoDifference(file, cache.file(for: url))
        expectNoDifference(try Data(contentsOf: file), clip)
        expectNoDifference(requests, [.started(path: "a.mp4", limited: false)])
    }

    @Test
    func `a play joins a running prefetch and keeps it when the card moves on`() async throws {
        await server.answer("a.mp4", with: .held(clip))
        let cache = cache()
        let url = server.url("a.mp4")
        var events = server.events.makeAsyncIterator()

        await cache.prefetch([url], for: owner)
        let started = await events.next()
        expectNoDifference(started, .started(path: "a.mp4", limited: true))
        #expect(await cache.beginPlaying(url) == nil)
        await cache.prefetch([], for: owner)
        await server.release("a.mp4")
        await cache.idle()

        expectNoDifference(try Data(contentsOf: cache.file(for: url)), clip)
        await server.finishEvents()
        var later = [StubClipServer.Event]()
        while let event = await events.next() {
            later.append(event)
        }
        #expect(!later.contains { if case .started = $0 { true } else { false } })
    }

    @Test
    func `a prefetch nobody wants any more stops and leaves nothing`() async throws {
        await server.answer("a.mp4", with: .held(clip))
        let cache = cache()
        var events = server.events.makeAsyncIterator()

        await cache.prefetch([server.url("a.mp4")], for: owner)
        let started = await events.next()
        expectNoDifference(started, .started(path: "a.mp4", limited: true))
        await cache.prefetch([], for: owner)

        let stopped = await events.next()
        expectNoDifference(stopped, .stopped(path: "a.mp4"))
        await cache.idle()
        expectNoDifference(try files(), [])
    }

    @Test(arguments: [StubClipServer.Answer.status(404), .dropped(Data(repeating: 7, count: 40))])
    func `a failed download leaves nothing that looks complete`(answer: StubClipServer.Answer) async throws {
        await server.answer("a.mp4", with: answer)
        let cache = cache()
        let url = server.url("a.mp4")

        #expect(await cache.beginPlaying(url) == nil)
        await cache.idle()

        expectNoDifference(try files(), [])
        #expect(await cache.beginPlaying(url) == nil)
    }

    @Test
    func `the least recently played clips go first once the folder passes its limit`() async throws {
        let cache = cache(sizeLimit: 250)
        let (a, _, c) = try await downloadThree(into: cache)
        try write(Data(), named: "cut-short.part")

        _ = await cache.beginPlaying(a)
        await cache.endPlaying(a)
        await cache.sweep()

        expectNoDifference(try files(), [a, c].map { cache.file(for: $0).lastPathComponent }.sorted())
    }

    @Test
    func `a clip playing now is never evicted`() async throws {
        let cache = cache(sizeLimit: 250)
        let (a, _, c) = try await downloadThree(into: cache)

        _ = await cache.beginPlaying(a)
        try date(cache.file(for: a), daysAgo: 4)
        await cache.sweep()

        expectNoDifference(try files(), [a, c].map { cache.file(for: $0).lastPathComponent }.sorted())
    }

    private func cache(sizeLimit: Int = 300 << 20) -> ClipCache {
        ClipCache(directory: directory, session: server.session, sizeLimit: sizeLimit)
    }

    /// Three 100-byte clips, dated three, two and one days ago.
    private func downloadThree(into cache: ClipCache) async throws -> (URL, URL, URL) {
        let urls = ["a.mp4", "b.mp4", "c.mp4"].map(server.url)
        for url in urls {
            await server.answer(url.lastPathComponent, with: .clip(clip))
        }
        await cache.prefetch(urls, for: owner)
        await cache.idle()
        await cache.prefetch([], for: owner)
        for (url, days) in zip(urls, [3, 2, 1]) {
            try date(cache.file(for: url), daysAgo: days)
        }
        return (urls[0], urls[1], urls[2])
    }

    private func startedRequests() async -> [StubClipServer.Event] {
        await server.finishEvents()
        var started = [StubClipServer.Event]()
        for await event in server.events {
            if case .started = event {
                started.append(event)
            }
        }
        return started
    }

    private func date(_ file: URL, daysAgo days: Int) throws {
        try FileManager.default.setAttributes(
            [.modificationDate: Date.now.addingTimeInterval(-Double(days) * 24 * 60 * 60)],
            ofItemAtPath: file.path(percentEncoded: false),
        )
    }

    private func write(_ data: Data, named name: String) throws {
        try data.write(to: directory.appending(path: name))
    }

    private func files() throws -> [String] {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return []
        }
        return try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false)).sorted()
    }
}
