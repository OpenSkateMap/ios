public import UIKit
import Vision

// MARK: - ImageClassifier

/// What's in a photo, computed on the device with Vision.
public struct ImageClassifier: Sendable {
    public var analyze: @Sendable (_ image: UIImage) async throws -> ImageAnalysis

    public init(analyze: @escaping @Sendable (_ image: UIImage) async throws -> ImageAnalysis) {
        self.analyze = analyze
    }
}

extension ImageClassifier {
    public static let live = ImageClassifier { image in
        guard let cgImage = image.cgImage else {
            return ImageAnalysis()
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        async let labels = ClassifyImageRequest().perform(on: cgImage, orientation: orientation)
        async let faces = DetectFaceRectanglesRequest().perform(on: cgImage, orientation: orientation)
        return try await ImageAnalysis(
            labels: Dictionary(labels.map { ($0.identifier, $0.confidence) }, uniquingKeysWith: max),
            largestFace: faces.map { Double($0.boundingBox.width * $0.boundingBox.height) }.max() ?? 0,
        )
    }

    public static let preview = ImageClassifier { _ in ImageAnalysis() }
}

// MARK: - ImageAnalysis

public struct ImageAnalysis: Equatable, Sendable {
    /// Vision's labels with their confidence, 0…1.
    public var labels: [String: Float]
    /// The share of the photo the largest face covers, 0…1.
    public var largestFace: Double

    public init(labels: [String: Float] = [:], largestFace: Double = 0) {
        self.labels = labels
        self.largestFace = largestFace
    }
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
