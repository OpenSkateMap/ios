public import Foundation

// MARK: - ClipPreparer

public struct ClipPreparer: Sendable {
    /// The seconds a clip may last; the server refuses one over 16 s.
    public static let durations: ClosedRange<Double> = 3...16

    /// `start` and `duration` in seconds of `source`; the window is cut to the video, then refused outside `durations`.
    public var prepare: @Sendable (_ source: URL, _ start: Double, _ duration: Double) async throws -> PreparedClip
    /// The frame at `at` seconds of `source`, prepared the way a picked photo is.
    public var poster: @Sendable (_ source: URL, _ at: Double) async throws -> PreparedPhoto

    public init(prepare: @escaping @Sendable (_ source: URL, _ start: Double, _ duration: Double) async throws -> PreparedClip,
                poster: @escaping @Sendable (_ source: URL, _ at: Double) async throws -> PreparedPhoto) {
        self.prepare = prepare
        self.poster = poster
    }
}

extension ClipPreparer {
    public static let live = ClipPreparer(
        prepare: { try await ClipPreparation.prepare($0, start: $1, duration: $2) },
        poster: { try await ClipPreparation.poster($0, at: $1) },
    )

    /// Encodes for real: nothing leaves the device.
    public static let preview = live

    /// Hands the source back as the clip and a one-pixel poster, without AVFoundation; a window outside `durations` is
    /// refused as the live one refuses it.
    public static let test = ClipPreparer(
        prepare: { source, _, duration in
            guard duration >= durations.lowerBound else {
                throw ClipPreparationError.tooShort
            }
            guard duration <= durations.upperBound else {
                throw ClipPreparationError.tooLong
            }
            return PreparedClip(file: source, width: 720, height: 1280, durationMs: Int((duration * 1000).rounded()), bytes: 0)
        },
        poster: { _, _ in PreparedPhoto(jpeg: Data(), width: 1, height: 1, thumbhash: "") },
    )
}
