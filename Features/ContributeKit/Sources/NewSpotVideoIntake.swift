import AVFoundation
import ComponentKit
import Foundation
import PhotoUploadKit
import UIKit

// MARK: - NewSpotVideoIntake

/// A pick's videos, one after another in pick order: Apple's trimmer, then the Cover Frame sheet, then the clip
/// prepared as that video's photo while the next one goes. Its tile shows as preparing all along; Cancel or ✕ takes it
/// away, and so does a clip that can't be made, with a toast saying why. Owns the picked and trimmed files.
final class NewSpotVideoIntake {

    // MARK: Types

    private struct Batch {
        var videos: [UUID]
        let then: () -> Void
    }

    // MARK: Computed Properties

    /// The trimmer and the sheet each wait for their own close, so they only go up over the form itself.
    private var freePresenter: UIViewController? {
        guard let presenter, presenter.viewIfLoaded?.window != nil, presenter.presentedViewController == nil else {
            return nil
        }
        return presenter
    }

    // MARK: Properties

    private weak var presenter: UIViewController?
    private let model: NewSpotModel
    private let tint: () -> UIColor?
    private var batches = [Batch]()
    /// Files that arrived for videos still waiting their turn; nil for one that couldn't be read.
    private var arrived = [UUID: URL?]()
    private var current: Task<Void, Never>?

    // MARK: Lifecycle

    init(model: NewSpotModel, presenter: UIViewController, tint: @escaping () -> UIColor?) {
        self.model = model
        self.presenter = presenter
        self.tint = tint
    }

    isolated deinit {
        current?.cancel()
        for case let file? in arrived.values {
            Self.remove(file)
        }
    }

    // MARK: Static Functions

    private static func remove(_ file: URL) {
        try? FileManager.default.removeItem(at: file)
    }

    @concurrent
    private nonisolated static func measure(_ file: URL) async throws -> (seconds: Double, size: CGSize) {
        let asset = AVURLAsset(url: file)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ClipPreparationError.unreadable
        }
        let duration = try await asset.load(.duration)
        let (naturalSize, transform) = try await track.load(.naturalSize, .preferredTransform)
        let size = naturalSize.applying(transform)
        return (duration.seconds, CGSize(width: abs(size.width), height: abs(size.height)))
    }

    private static func showFailure(_ error: any Error) {
        let reason =
            switch error as? ClipPreparationError {
            case .tooShort: ContributeKitStrings.NewSpot.Clip.Failed.tooShort
            case .unreadable: ContributeKitStrings.NewSpot.Clip.Failed.unreadable
            case .tooLong, .encoding, nil: ContributeKitStrings.NewSpot.Clip.Failed.encoding
            }
        ToastView.showFailure(ContributeKitStrings.NewSpot.Clip.Failed.title, subtitle: reason)
    }

    // MARK: Functions

    /// `videos` are a pick's video tiles in pick order; `then` runs once each is a clip on its way or gone.
    func begin(_ videos: [UUID], then: @escaping () -> Void) {
        batches.append(Batch(videos: videos, then: then))
        advance()
    }

    /// The file for the video tile `id`, which the intake now owns; nil when it couldn't be read.
    func receive(_ file: URL?, for id: UUID) {
        arrived[id] = .some(file)
        advance()
    }

    private func advance() {
        guard current == nil else {
            return
        }
        while let batch = batches.first, batch.videos.isEmpty {
            batches.removeFirst()
            batch.then()
        }
        guard let id = batches.first?.videos.first, let file = arrived.removeValue(forKey: id) else {
            return
        }
        current = Task { [weak self] in
            await self?.take(id, file: file)
            guard let self else {
                return
            }
            current = nil
            batches[0].videos.removeFirst()
            advance()
        }
    }

    private func take(_ id: UUID, file: URL?) async {
        guard let file else {
            drop(id, because: ClipPreparationError.unreadable)
            return
        }
        guard model.form.photos[id: id] != nil, let presenter = freePresenter else {
            Self.remove(file)
            model.removePhoto(id)
            return
        }
        let source: URL
        if UIVideoEditorController.canEditVideo(atPath: file.path) {
            switch await VideoTrimmer().trim(file, from: presenter) {
            case .saved(let trimmed):
                if trimmed != file {
                    Self.remove(file)
                }
                source = trimmed

            case .cancelled:
                Self.remove(file)
                model.removePhoto(id)
                return

            case .failed:
                Self.remove(file)
                drop(id, because: ClipPreparationError.unreadable)
                return
            }
        } else {
            // Without the trimmer the clip is the video's first seconds, up to the longest a clip runs.
            source = file
        }
        await chooseCover(of: id, in: source)
    }

    private func chooseCover(of id: UUID, in source: URL) async {
        let video: (seconds: Double, size: CGSize)
        do {
            video = try await Self.measure(source)
        } catch {
            Self.remove(source)
            drop(id, because: error)
            return
        }
        guard video.seconds >= ClipPreparer.durations.lowerBound else {
            Self.remove(source)
            drop(id, because: ClipPreparationError.tooShort)
            return
        }
        let duration = min(video.seconds, ClipPreparer.durations.upperBound)
        guard let cover = await askForCover(in: source, duration: duration, size: video.size),
              model.form.photos[id: id] != nil else {
            Self.remove(source)
            model.removePhoto(id)
            return
        }
        Task { [model] in
            do {
                try await model.fillClip(id, from: source, duration: duration, coverAt: cover)
            } catch is CancellationError {
                // The photo was removed meanwhile.
            } catch {
                Self.showFailure(error)
            }
            Self.remove(source)
        }
    }

    /// The seconds into the clip of the frame chosen; nil when the sheet closed without one.
    private func askForCover(in source: URL, duration: Double, size: CGSize) async -> Double? {
        guard let presenter = freePresenter else {
            return nil
        }
        let picker = CoverFramePickerView(file: source, duration: duration, displaySize: size)
        return await withCheckedContinuation { continuation in
            var chosen: Double?
            let sheet = OptionSheetViewController(
                title: ContributeKitStrings.NewSpot.CoverFrame.title,
                message: ContributeKitStrings.NewSpot.CoverFrame.message,
                content: picker,
                tint: tint(),
                confirmTitle: ContributeKitStrings.NewSpot.CoverFrame.confirm,
            ) { [weak picker] in
                chosen = picker?.time
            }
            sheet.onClose = {
                continuation.resume(returning: chosen)
            }
            presenter.present(sheet, animated: true)
        }
    }

    private func drop(_ id: UUID, because error: any Error) {
        guard model.form.photos[id: id] != nil else {
            return
        }
        model.removePhoto(id)
        Self.showFailure(error)
    }
}
