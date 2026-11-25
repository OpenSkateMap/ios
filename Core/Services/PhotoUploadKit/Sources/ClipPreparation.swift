import AVFoundation
import CoreMedia
import Foundation

// MARK: - ClipPreparation

enum ClipPreparation {

    // MARK: Types

    typealias Samples = AVAssetReaderOutput.Provider<CMReadySampleBuffer<CMSampleBuffer.DynamicContent>>

    // MARK: Static Properties

    static let maxShortSide = 720.0
    /// The server refuses a side over 1920.
    static let maxLongSide = 1920.0
    static let maxFrameRate: Float = 30
    /// About 3.6 MB for the longest clip, well under the server's 15 MB.
    static let averageBitRate = 1_800_000
    static let soundBitRatePerChannel = 64000

    private static let colorProperties = [
        AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
        AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
        AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
    ]

    // MARK: Static Functions

    @concurrent
    static func prepare(_ source: URL, start: Double, duration: Double) async throws -> PreparedClip {
        let asset = AVURLAsset(url: source)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ClipPreparationError.unreadable
        }
        let length = try await asset.load(.duration)
        let window = try window(start: start, duration: duration, within: length.seconds)
        let (naturalSize, transform, frameRate) = try await track.load(.naturalSize, .preferredTransform, .nominalFrameRate)
        guard let geometry = Geometry(naturalSize: naturalSize, transform: transform) else {
            throw ClipPreparationError.unreadable
        }
        let fps = frameRate > 0 ? min(frameRate, maxFrameRate) : maxFrameRate

        let reader = try AVAssetReader(asset: asset)
        // A read window past the composition's end is refused (-11841), so it never runs past the asset.
        reader.timeRange = CMTimeRangeGetIntersection(window, otherRange: CMTimeRange(start: .zero, duration: length))
        let output = AVAssetReaderVideoCompositionOutput(
            videoTracks: [track],
            videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
        )
        output.videoComposition = composition(track, geometry, fps: fps, length: length)
        output.alwaysCopiesSampleData = false

        let file = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: file, fileType: .mp4)
        // The index (moov) goes before the media, as the server requires; no metadata is written.
        writer.shouldOptimizeForNetworkUse = true
        writer.metadata = []
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: geometry.width,
            AVVideoHeightKey: geometry.height,
            AVVideoColorPropertiesKey: colorProperties,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: averageBitRate,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoMaxKeyFrameIntervalDurationKey: 2,
            ],
        ])
        input.expectsMediaDataInRealTime = false
        let sound = try await Sound(of: asset, reader: reader, writer: writer)

        // These attach the outputs and the inputs; adding them as well leaves the receivers waiting forever.
        let pictures = reader.outputProvider(for: output)
        let pictureReceiver = writer.inputReceiver(for: input)
        var sounds: Samples?
        var soundReceiver: AVAssetWriterInput.SampleBufferReceiver?
        if let sound {
            sounds = reader.outputProvider(for: sound.output)
            soundReceiver = writer.inputReceiver(for: sound.input)
        }
        do {
            try reader.start()
            try writer.start()
            writer.startSession(atSourceTime: window.start)
            // Fed side by side: the writer interleaves, so an input ahead of the other waits for it.
            async let picture: Void = copy(pictures, into: pictureReceiver)
            async let soundtrack: Void = copy(sounds, into: soundReceiver)
            _ = try await (picture, soundtrack)
            if reader.status == .failed {
                throw reader.error ?? ClipPreparationError.encoding
            }
            writer.endSession(atSourceTime: window.end)
            await writer.finishWriting()
            guard writer.status == .completed else {
                throw writer.error ?? ClipPreparationError.encoding
            }
            try MP4BoxTimes.clear(in: file)
        } catch {
            reader.cancelReading()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: file)
            throw error
        }

        let written = try await AVURLAsset(url: file).load(.duration)
        return try PreparedClip(
            file: file,
            width: geometry.width,
            height: geometry.height,
            durationMs: Int((written.seconds * 1000).rounded()),
            bytes: file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0,
        )
    }

    @concurrent
    static func poster(_ source: URL, at seconds: Double) async throws -> PreparedPhoto {
        let asset = AVURLAsset(url: source)
        let length = try await asset.load(.duration)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        generator.maximumSize = CGSize(width: PhotoPreparation.maxPixelSize, height: PhotoPreparation.maxPixelSize)
        let time = CMTime(seconds: min(max(0, seconds), length.seconds), preferredTimescale: length.timescale)
        return try await PhotoPreparation.encode(generator.image(at: time).image)
    }

    /// `start` and `duration` cut to the video, in whole milliseconds as the server measures them, never past its end.
    static func window(start: Double, duration: Double, within length: Double) throws -> CMTimeRange {
        let from = min(max(0, start), length)
        let to = min(max(from, start + duration), length)
        let milliseconds = Int(((to - from) * 1000).rounded(.down))
        guard milliseconds >= Int(ClipPreparer.durations.lowerBound * 1000) else {
            throw ClipPreparationError.tooShort
        }
        guard milliseconds <= Int(ClipPreparer.durations.upperBound * 1000) else {
            throw ClipPreparationError.tooLong
        }
        return CMTimeRange(
            start: CMTime(seconds: from, preferredTimescale: 600),
            duration: CMTime(value: CMTimeValue(milliseconds), timescale: 1000),
        )
    }

    private static func copy(_ samples: sending Samples?,
                             into receiver: sending AVAssetWriterInput.SampleBufferReceiver?) async throws {
        guard let samples, let receiver else {
            return
        }
        while let sample = try await samples.next() {
            try Task.checkCancellation()
            try await receiver.append(sample)
        }
        receiver.finish()
    }

    private static func composition(_ track: AVAssetTrack,
                                    _ geometry: Geometry,
                                    fps: Float,
                                    length: CMTime) -> AVVideoComposition {
        var layer = AVVideoCompositionLayerInstruction.Configuration(assetTrack: track)
        layer.setTransform(geometry.placement, at: .zero)
        let instruction = AVVideoCompositionInstruction(configuration: .init(
            layerInstructions: [AVVideoCompositionLayerInstruction(configuration: layer)],
            timeRange: CMTimeRange(start: .zero, duration: length),
        ))
        // Rec. 709 throughout, so HDR footage is tone mapped rather than written as washed-out SDR.
        return AVVideoComposition(configuration: .init(
            colorPrimaries: AVVideoColorPrimaries_ITU_R_709_2,
            colorTransferFunction: AVVideoTransferFunction_ITU_R_709_2,
            colorYCbCrMatrix: AVVideoYCbCrMatrix_ITU_R_709_2,
            frameDuration: CMTime(value: CMTimeValue((600 / fps).rounded()), timescale: 600),
            instructions: [instruction],
            renderSize: CGSize(width: geometry.width, height: geometry.height),
        ))
    }
}

// MARK: ClipPreparation.Sound

extension ClipPreparation {
    /// The source's sound as AAC at its own rate, at most stereo; nil without sound, or with sound neither side can handle.
    struct Sound {

        // MARK: Properties

        let output: AVAssetReaderTrackOutput
        let input: AVAssetWriterInput

        // MARK: Lifecycle

        init?(of asset: AVURLAsset, reader: AVAssetReader, writer: AVAssetWriter) async throws {
            // A phone's spatial recording adds a four-channel track that's switched off; the stereo one is on.
            var enabled: AVAssetTrack?
            for track in try await asset.loadTracks(withMediaType: .audio) {
                if try await track.load(.isEnabled) {
                    enabled = track
                    break
                }
            }
            guard let track = enabled else {
                return nil
            }
            let source = try await track.load(.formatDescriptions).first
                .flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
            let sampleRate = source?.mSampleRate == 44100 ? 44100.0 : 48000.0
            let channels = min(max(Int(source?.mChannelsPerFrame ?? 2), 1), 2)
            output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false,
            ])
            output.alwaysCopiesSampleData = false
            input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderBitRateKey: channels * ClipPreparation.soundBitRatePerChannel,
            ])
            input.expectsMediaDataInRealTime = false
            guard reader.canAdd(output), writer.canAdd(input) else {
                return nil
            }
        }
    }
}

// MARK: ClipPreparation.Geometry

extension ClipPreparation {
    /// The track turned upright, then scaled to fit both side limits without growing, on even pixels.
    struct Geometry {

        // MARK: Properties

        let width: Int
        let height: Int
        /// The track's own transform, moved back to the origin and scaled to `width` × `height`.
        let placement: CGAffineTransform

        // MARK: Lifecycle

        init?(naturalSize: CGSize, transform: CGAffineTransform) {
            let upright = CGRect(origin: .zero, size: naturalSize).applying(transform)
            guard upright.width > 0, upright.height > 0 else {
                return nil
            }
            let scale = min(
                1,
                ClipPreparation.maxShortSide / min(upright.width, upright.height),
                ClipPreparation.maxLongSide / max(upright.width, upright.height),
            )
            width = Self.even(upright.width * scale)
            height = Self.even(upright.height * scale)
            placement = transform
                .concatenating(CGAffineTransform(translationX: -upright.minX, y: -upright.minY))
                .concatenating(CGAffineTransform(scaleX: CGFloat(width) / upright.width, y: CGFloat(height) / upright.height))
        }

        // MARK: Static Functions

        /// H.264 4:2:0 needs even sides; rounding down never grows the picture.
        private static func even(_ side: CGFloat) -> Int {
            max(2, Int(side.rounded()) / 2 * 2)
        }
    }
}
