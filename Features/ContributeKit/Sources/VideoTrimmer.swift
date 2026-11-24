import os
import PhotoUploadKit
import UIKit

// MARK: - VideoTrimmer

/// Apple's trimmer for one picked video, with its own Cancel and Save.
final class VideoTrimmer: NSObject {

    // MARK: Types

    enum Outcome: Equatable {
        /// The trimmed copy, which the caller owns; it can be the picked file itself.
        case saved(URL)
        case cancelled
        case failed
    }

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "new-spot")

    // MARK: Properties

    private var continuation: CheckedContinuation<Outcome, Never>?

    // MARK: Functions

    func trim(_ file: URL, from presenter: UIViewController) async -> Outcome {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            let editor = UIVideoEditorController()
            editor.videoPath = file.path
            editor.videoMaximumDuration = ClipPreparer.durations.upperBound
            editor.videoQuality = .typeHigh
            editor.delegate = self
            // Only Cancel and Save close it: a swipe down would leave the delegate unanswered.
            editor.modalPresentationStyle = .fullScreen
            presenter.present(editor, animated: true)
        }
    }

    private func finish(_ editor: UIVideoEditorController, with outcome: Outcome) {
        // Save can be reported twice.
        guard let continuation else {
            return
        }
        self.continuation = nil
        editor.dismiss(animated: true) {
            continuation.resume(returning: outcome)
        }
    }
}

// MARK: UIVideoEditorControllerDelegate, UINavigationControllerDelegate

extension VideoTrimmer: UIVideoEditorControllerDelegate, UINavigationControllerDelegate {
    func videoEditorController(_ editor: UIVideoEditorController, didSaveEditedVideoToPath editedVideoPath: String) {
        finish(editor, with: .saved(URL(fileURLWithPath: editedVideoPath)))
    }

    func videoEditorControllerDidCancel(_ editor: UIVideoEditorController) {
        finish(editor, with: .cancelled)
    }

    func videoEditorController(_ editor: UIVideoEditorController, didFailWithError error: any Error) {
        Self.logger.error("The trimmer failed: \(String(describing: type(of: error)), privacy: .public)")
        finish(editor, with: .failed)
    }
}
