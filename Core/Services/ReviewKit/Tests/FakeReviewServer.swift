import Foundation
import SpotModelKit
import Synchronization
@testable import ReviewKit

// MARK: - FakeReviewServer

final class FakeReviewServer: Sendable {

    // MARK: Types

    struct State {
        var queue = [ReviewCard]()
        var videos = [VideoReviewCard]()
        var cityIDs: [String]?
        var calls = [String]()
        var failNext: ReviewAPIError?
        var holdsQueue = false
        var heldQueue: CheckedContinuation<Void, Never>?
        var holdsUndo = false
        var heldUndo: CheckedContinuation<Void, Never>?
        var now = Date(timeIntervalSince1970: 1_791_590_400)
    }

    // MARK: Computed Properties

    var calls: [String] {
        state.withLock(\.calls)
    }

    var api: ReviewAPIManager {
        ReviewAPIManager(
            queue: { [self] _, _ in
                let (answer, holds) = try state.withLock { state in
                    state.calls.append("queue")
                    if let failure = state.failNext.take() {
                        throw failure
                    }
                    let holds = state.holdsQueue
                    state.holdsQueue = false
                    return (ReviewQueue(cityIDs: state.cityIDs, cards: state.queue, videos: state.videos), holds)
                }
                if holds {
                    // Held first, then reported, so a release right after the report always finds it.
                    await withCheckedContinuation { continuation in
                        state.withLock { $0.heldQueue = continuation }
                        queueRequests.continuation.yield()
                    }
                }
                return answer
            },
            approve: { [self] id, edits, seen in
                try decide(id, call: "approve \(id) seen=\(Self.stamp(seen)) edits=\(Self.describe(edits))", status: .approved)
            },
            reject: { [self] id, reason, seen in
                try decide(id, call: "reject \(id) \(reason.rawValue) seen=\(Self.stamp(seen))", status: .rejected)
            },
            undo: { [self] id in
                let holds = state.withLock { state in
                    defer { state.holdsUndo = false }
                    return state.holdsUndo
                }
                if holds {
                    await withCheckedContinuation { continuation in
                        state.withLock { $0.heldUndo = continuation }
                        undoRequests.continuation.yield()
                    }
                }
                return try state.withLock { state in
                    state.calls.append("undo \(id)")
                    if let failure = state.failNext.take() {
                        throw failure
                    }
                    state.now += 1
                    return ReviewDecided(id: id, status: .pending, spotID: "spot-\(id)", updatedAt: state.now)
                }
            },
            approveVideo: { [self] id, seen in
                try decideVideo(id, call: "approveVideo \(id) seen=\(Self.stamp(seen))")
            },
            rejectVideo: { [self] id, reason, seen in
                try decideVideo(id, call: "rejectVideo \(id) \(reason.rawValue) seen=\(Self.stamp(seen))")
            },
            undoVideo: { [self] id in
                try decideVideo(id, call: "undoVideo \(id)")
            },
        )
    }

    var queueHeld: AsyncStream<Void> {
        queueRequests.stream
    }

    var undoHeld: AsyncStream<Void> {
        undoRequests.stream
    }

    // MARK: Properties

    private let state = Mutex(State())
    private let queueRequests = AsyncStream<Void>.makeStream()
    private let undoRequests = AsyncStream<Void>.makeStream()

    // MARK: Lifecycle

    init(cards: [ReviewCard] = [], cityIDs: [String]? = ["london"]) {
        state.withLock {
            $0.queue = cards
            $0.cityIDs = cityIDs
        }
    }

    // MARK: Static Functions

    static func stamp(_ date: Date) -> String {
        String(Int(date.timeIntervalSince1970))
    }

    static func describe(_ edits: SpotEdits) -> String {
        var parts = [String]()
        if let title = edits.title {
            parts.append("title=\(title)")
        }
        if let kind = edits.kind {
            parts.append("kind=\(kind.rawValue)")
        }
        if let obstacles = edits.obstacles {
            parts.append("obstacles=\(obstacles.joined(separator: ","))")
        }
        if let coordinate = edits.coordinate {
            parts.append("pin=\(coordinate.latitude),\(coordinate.longitude)")
        }
        if let photoIDs = edits.photoIDs {
            parts.append("photos=\(photoIDs.joined(separator: ","))")
        }
        return parts.isEmpty ? "none" : parts.joined(separator: ";")
    }

    // MARK: Functions

    func holdNextQueue() {
        state.withLock { $0.holdsQueue = true }
    }

    func releaseQueue() {
        state.withLock { $0.heldQueue.take() }?.resume()
    }

    func holdNextUndo() {
        state.withLock { $0.holdsUndo = true }
    }

    func releaseUndo() {
        state.withLock { $0.heldUndo.take() }?.resume()
    }

    func setQueue(_ cards: [ReviewCard]) {
        state.withLock { $0.queue = cards }
    }

    func setVideos(_ videos: [VideoReviewCard]) {
        state.withLock { $0.videos = videos }
    }

    func failNext(_ error: ReviewAPIError) {
        state.withLock { $0.failNext = error }
    }

    private func decideVideo(_ id: String, call: String) throws -> VideoDecided {
        try state.withLock { state in
            state.calls.append(call)
            if let failure = state.failNext.take() {
                throw failure
            }
            state.videos.removeAll { $0.id == id }
            state.now += 1
            return VideoDecided(id: id, updatedAt: state.now)
        }
    }

    private func decide(_ id: String, call: String, status: SubmissionStatus) throws -> ReviewDecided {
        try state.withLock { state in
            state.calls.append(call)
            if let failure = state.failNext.take() {
                throw failure
            }
            state.queue.removeAll { $0.id == id }
            state.now += 1
            return ReviewDecided(id: id, status: status, spotID: status == .approved ? "spot-\(id)" : nil, updatedAt: state.now)
        }
    }
}

extension ReviewCard {
    static func fixture(_ id: String, title: String = "Ledges", updatedAt: Int = 1_791_500_000) -> ReviewCard {
        ReviewCard(
            id: id,
            title: title,
            about: "",
            kind: .street,
            obstacles: ["ledges"],
            condition: .skateable,
            latitude: 51.5066,
            longitude: -0.1169,
            cityID: "london",
            note: "",
            photos: [
                Photo(
                    id: "\(id)-p0",
                    key: "photos/0.jpg",
                    width: 640,
                    height: 480,
                    thumbhash: "1QcSHQRnh493V4dIh4eXh1h4kJUI",
                    credit: .submitter,
                    isExisting: false,
                ),
                Photo(
                    id: "\(id)-p1",
                    key: "photos/1.jpg",
                    width: 480,
                    height: 640,
                    thumbhash: "2QcSHQRnh493V4dIh4eXh1h4kJUI",
                    credit: .someoneElse(name: "@lens", sourceURL: nil),
                    isExisting: false,
                ),
            ],
            submitterName: "Rider",
            nearby: [],
            createdAt: Date(timeIntervalSince1970: 1_791_400_000),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedAt)),
        )
    }
}

extension Optional {
    mutating func take() -> Wrapped? {
        defer { self = nil }
        return self
    }
}

extension VideoReviewCard {
    static func fixture(_ id: String, updatedAt: Int = 1_791_500_000) -> VideoReviewCard {
        VideoReviewCard(
            id: id,
            spotID: "spot-\(id)",
            spotTitle: "Undercroft",
            spotKind: .plaza,
            cityID: "london",
            provider: .youtube,
            url: URL(string: "https://www.youtube.com/watch?v=dQw4w9WgXcQ")!,
            thumbnailURL: URL(string: "https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg"),
            caption: "Kickflip",
            submitterName: "Rider",
            createdAt: Date(timeIntervalSince1970: TimeInterval(updatedAt)),
            updatedAt: Date(timeIntervalSince1970: TimeInterval(updatedAt)),
        )
    }
}
