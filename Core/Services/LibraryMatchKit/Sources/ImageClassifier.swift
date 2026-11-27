public import UIKit
import Vision

// MARK: - ImageClassifier

/// What's in a photo, as Vision's labels with their confidence, computed on the device.
public struct ImageClassifier: Sendable {
    public var labels: @Sendable (_ image: UIImage) async throws -> [String: Float]

    public init(labels: @escaping @Sendable (_ image: UIImage) async throws -> [String: Float]) {
        self.labels = labels
    }
}

extension ImageClassifier {
    public static let live = ImageClassifier { image in
        guard let cgImage = image.cgImage else {
            return [:]
        }
        let observations = try await ClassifyImageRequest().perform(
            on: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
        )
        return Dictionary(observations.map { ($0.identifier, $0.confidence) }, uniquingKeysWith: max)
    }

    public static let preview = ImageClassifier { _ in [:] }
}

// MARK: - CGImagePropertyOrientation + UIImage.Orientation

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
