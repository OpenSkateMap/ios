import Foundation
import Synchronization
import UIKit
@testable import LibraryMatchKit

// MARK: - FakePhotoLibrary

/// A photo library in memory with Vision's answers set by hand. Each change bumps a version, which a token names, so a
/// read since a token returns what was added or deleted after it.
final class FakePhotoLibrary: Sendable {

    // MARK: Types

    struct State {
        var access = PhotoAccess.notDetermined
        /// What the system's prompt answers.
        var answer = PhotoAccess.full
        var prompts = 0
        var version = 0
        var assets = [String: (asset: LibraryAsset, version: Int)]()
        var deleted = [String: Int]()
        var labels = [String: [String: Float]]()
        var images = [String: UIImage]()
        var owners = [ObjectIdentifier: String]()
        var reads = [String]()
        var expiresTokens = false
        var holdsRead = false
        var heldReads = [UUID: CheckedContinuation<Void, Never>]()
        var cancelledReads = Set<UUID>()
    }

    // MARK: Computed Properties

    var reads: [String] {
        state.withLock(\.reads)
    }

    var prompts: Int {
        state.withLock(\.prompts)
    }

    var library: PhotoLibrary {
        PhotoLibrary { [self] in
            state.withLock(\.access)
        } requestAccess: { [self] in
            state.withLock { state in
                if state.access == .notDetermined {
                    state.prompts += 1
                    state.access = state.answer
                }
                return state.access
            }
        } changes: { [self] token in
            let holds = state.withLock { state in
                defer { state.holdsRead = false }
                return state.holdsRead
            }
            if holds {
                await hold()
                guard !Task.isCancelled else {
                    return LibraryChanges(isComplete: false, assets: [], deletedIDs: [], token: nil)
                }
            }
            return state.withLock { state in
                let since = token.flatMap { String(data: $0, encoding: .utf8) }.flatMap(Int.init)
                let newToken = Data(String(state.version).utf8)
                guard let since, !state.expiresTokens else {
                    state.reads.append("all")
                    return LibraryChanges(
                        isComplete: true,
                        assets: state.assets.values.map(\.asset).sorted { $0.id < $1.id },
                        deletedIDs: [],
                        token: newToken,
                    )
                }
                state.reads.append("since \(since)")
                return LibraryChanges(
                    isComplete: false,
                    assets: state.assets.values.filter { $0.version > since }.map(\.asset).sorted { $0.id < $1.id },
                    deletedIDs: Set(state.deleted.filter { $0.value > since }.keys),
                    token: newToken,
                )
            }
        } image: { [self] assetID, _, _ in
            state.withLock { $0.images[assetID] }
        } imageData: { assetID in
            Data(assetID.utf8)
        }
    }

    var classifier: ImageClassifier {
        ImageClassifier { [self] image in
            state.withLock { state in
                state.owners[ObjectIdentifier(image)].flatMap { state.labels[$0] } ?? [:]
            }
        }
    }

    // MARK: Properties

    let readHeld: AsyncStream<Void>

    private let state = Mutex(State())
    private let reportHeld: AsyncStream<Void>.Continuation

    // MARK: Lifecycle

    init(access: PhotoAccess = .notDetermined) {
        (readHeld, reportHeld) = AsyncStream.makeStream()
        state.withLock { $0.access = access }
    }

    // MARK: Functions

    func add(_ asset: LibraryAsset, labels: [String: Float] = [:]) {
        state.withLock { state in
            state.version += 1
            state.assets[asset.id] = (asset, state.version)
            state.labels[asset.id] = labels
            let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { _ in }
            state.images[asset.id] = image
            state.owners[ObjectIdentifier(image)] = asset.id
        }
    }

    func delete(_ assetID: String) {
        state.withLock { state in
            state.version += 1
            state.assets[assetID] = nil
            state.deleted[assetID] = state.version
        }
    }

    func setAccess(_ access: PhotoAccess) {
        state.withLock { $0.access = access }
    }

    func answerPrompt(with access: PhotoAccess) {
        state.withLock { $0.answer = access }
    }

    func expireTokens() {
        state.withLock { $0.expiresTokens = true }
    }

    func holdNextRead() {
        state.withLock { $0.holdsRead = true }
    }

    func releaseReads() {
        let held = state.withLock { state in
            defer { state.heldReads = [:] }
            return state.heldReads.values
        }
        for continuation in held {
            continuation.resume()
        }
    }

    /// Held first, then reported, so a release right after the report always finds it; cancelling the reader lets it go,
    /// as a read that stops when its scan is cancelled.
    private func hold() async {
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let isCancelled = state.withLock { state in
                    guard !state.cancelledReads.contains(id) else {
                        return true
                    }
                    state.heldReads[id] = continuation
                    return false
                }
                if isCancelled {
                    continuation.resume()
                } else {
                    reportHeld.yield()
                }
            }
        } onCancel: {
            state.withLock { state in
                state.cancelledReads.insert(id)
                return state.heldReads.removeValue(forKey: id)
            }?.resume()
        }
    }
}
