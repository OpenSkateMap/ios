import AVFoundation
import CoreMedia
import CoreVideo
import CustomDump
import Foundation
import ImageKit
import Testing
@testable import PhotoUploadKit

// MARK: - ClipPreparationTests

@Suite(.timeLimit(.minutes(1)))
struct ClipPreparationTests {
    /// Recorded sideways with sound, as a phone held upright records it: 1600 × 900 pixels turned a quarter.
    private static let portrait = TestVideo(width: 1600, height: 900, seconds: 5, framesPerSecond: 30, turned: true)

    @Test
    func `a window comes out upright, at most 720 on its short side, H.264 with its sound as AAC, and indexed before its media`() async throws {
        let source = try await Self.portrait.write()
        defer { try? FileManager.default.removeItem(at: source) }
        let sourceAsset = AVURLAsset(url: source)
        #expect(try await !sourceAsset.loadTracks(withMediaType: .audio).isEmpty)

        let clip = try await ClipPreparation.prepare(source, start: 1, duration: 3)
        defer { try? FileManager.default.removeItem(at: clip.file) }

        let asset = AVURLAsset(url: clip.file)
        let tracks = try await asset.load(.tracks)
        expectNoDifference(tracks.map(\.mediaType), [.video, .audio])
        let sound = try await tracks[1].load(.formatDescriptions)
        expectNoDifference(sound.map(\.mediaSubType), [.mpeg4AAC])
        let track = try #require(tracks.first)
        let (size, transform, formats) = try await track.load(.naturalSize, .preferredTransform, .formatDescriptions)
        expectNoDifference(formats.map(\.mediaSubType), [.h264])
        #expect(transform.isIdentity)
        expectNoDifference([Int(size.width), Int(size.height)], [720, 1280])
        expectNoDifference([clip.width, clip.height], [720, 1280])
        #expect(abs(clip.durationMs - 3000) <= 34)
        let duration = try await asset.load(.duration)
        #expect(abs(duration.seconds - 3) <= 1.0 / 30)
        #expect(try await asset.load(.metadata).isEmpty)
        #expect(try await asset.load(.creationDate) == nil)
        expectNoDifference(try headerTimes(clip.file), [0, 0])

        let boxes = try topLevelBoxes(clip.file)
        let moov = try #require(boxes.firstIndex(of: "moov"))
        let mdat = try #require(boxes.firstIndex(of: "mdat"))
        #expect(moov < mdat)
        #expect(!boxes.contains("moof"))
        let bytes = try clip.file.resourceValues(forKeys: [.fileSizeKey]).fileSize
        expectNoDifference(clip.bytes, bytes)
    }

    @Test
    func `a video without sound comes out with its picture alone`() async throws {
        let source = try await TestVideo(width: 64, height: 36, seconds: 4, framesPerSecond: 2, turned: false, sound: false)
            .write()
        defer { try? FileManager.default.removeItem(at: source) }

        let clip = try await ClipPreparation.prepare(source, start: 0, duration: 4)
        defer { try? FileManager.default.removeItem(at: clip.file) }

        let tracks = try await AVURLAsset(url: clip.file).load(.tracks)
        expectNoDifference(tracks.map(\.mediaType), [.video])
    }

    @Test
    func `windows shorter than three seconds or longer than sixteen are refused, after cutting them to the video`() async throws {
        let long = try await TestVideo(width: 64, height: 36, seconds: 17, framesPerSecond: 2, turned: false).write()
        defer { try? FileManager.default.removeItem(at: long) }

        await #expect(throws: ClipPreparationError.tooShort) {
            try await ClipPreparation.prepare(long, start: 0, duration: 2.9)
        }
        await #expect(throws: ClipPreparationError.tooShort) {
            try await ClipPreparation.prepare(long, start: 15, duration: 5)
        }
        await #expect(throws: ClipPreparationError.tooLong) {
            try await ClipPreparation.prepare(long, start: 0, duration: 16.5)
        }
        await #expect(throws: ClipPreparationError.tooLong) {
            try await ClipPreparation.prepare(long, start: 0, duration: 30)
        }
        expectNoDifference(try ClipPreparation.window(start: 1, duration: 30, within: 17).duration.seconds, 16)
    }

    @Test
    func `a window never runs past a video whose length isn't whole milliseconds`() throws {
        let length = 11.515_642
        let window = try ClipPreparation.window(start: 0, duration: length, within: length)

        #expect(window.end.seconds <= length)
        expectNoDifference(Int((window.duration.seconds * 1000).rounded()), 11515)
    }

    @Test
    func `the poster is the frame at that moment, upright, as an ordinary photo`() async throws {
        let source = try await Self.portrait.write()
        defer { try? FileManager.default.removeItem(at: source) }

        let poster = try await ClipPreparation.poster(source, at: 2)

        expectNoDifference([poster.width, poster.height], [900, 1600])
        let hash = try #require(ThumbHash.bytes(fromBase64: poster.thumbhash))
        #expect(ThumbHash.decode(hash) != nil)
    }

    // MARK: Helpers

    /// The movie header's creation and modification times.
    private func headerTimes(_ file: URL) throws -> [UInt32] {
        let data = try Data(contentsOf: file)
        let mvhd = try #require(data.range(of: Data("mvhd".utf8)))
        let times = mvhd.upperBound + 4
        return [times, times + 4].map { start in data[start..<start + 4].reduce(0) { $0 << 8 | UInt32($1) } }
    }

    /// The type of each top-level MP4 box, in file order.
    private func topLevelBoxes(_ file: URL) throws -> [String] {
        let data = try Data(contentsOf: file)
        var types = [String]()
        var offset = 0
        while offset + 8 <= data.count {
            let size32 = data[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) }
            types.append(String(decoding: data[offset + 4..<offset + 8], as: UTF8.self))
            let size =
                switch size32 {
                case 0: data.count - offset
                case 1: data[offset + 8..<offset + 16].reduce(0) { $0 << 8 | Int($1) }
                default: size32
                }
            guard size >= 8 else {
                break
            }
            offset += size
        }
        return types
    }
}

// MARK: - TestVideo

/// A source video written in the test: a shade that changes every frame, and silence on a sound track unless `sound` is off.
/// `framesPerSecond` divides 44 100, the sound's sample rate.
private struct TestVideo {

    // MARK: Properties

    let width: Int
    let height: Int
    let seconds: Int
    let framesPerSecond: Int
    let turned: Bool
    var sound = true

    // MARK: Functions

    func write() async throws -> URL {
        let file = URL.temporaryDirectory.appending(path: "Source \(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: file, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        if turned {
            // What a phone held upright writes: the pixels stay landscape, the matrix turns them.
            video.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: CGFloat(height), ty: 0)
        }
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
        ])
        let frames = writer.inputPixelBufferReceiver(for: video, pixelBufferAttributes: nil)
        let silence = sound ? writer.inputReceiver(for: audio) : nil
        try writer.start()
        writer.startSession(atSourceTime: .zero)

        // Fed side by side: an input ahead of the other waits for it to interleave, past the encoders' delay.
        async let pictures: Void = feed(frames)
        async let soundtrack: Void = feed(silence)
        _ = try await (pictures, soundtrack)
        await writer.finishWriting()
        if let error = writer.error {
            throw error
        }
        return file
    }

    private func feed(_ frames: sending AVAssetWriterInput.PixelBufferReceiver) async throws {
        for index in 0..<seconds * framesPerSecond {
            try await frames.append(
                frame(index),
                with: CMTime(value: CMTimeValue(index), timescale: CMTimeScale(framesPerSecond)),
            )
        }
        frames.finish()
    }

    private func feed(_ sound: sending AVAssetWriterInput.SampleBufferReceiver?) async throws {
        guard let sound else {
            return
        }
        for index in 0..<seconds * framesPerSecond {
            try await sound.append(silence(frame: index))
        }
        sound.finish()
    }

    private func frame(_ index: Int) throws -> CVReadOnlyPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
        let pixels = try #require(buffer, "CVPixelBufferCreate: \(status)")
        CVPixelBufferLockBaseAddress(pixels, [])
        let base = CVPixelBufferGetBaseAddress(pixels)
        memset(base, Int32(index * 7 % 256), CVPixelBufferGetDataSize(pixels))
        CVPixelBufferUnlockBaseAddress(pixels, [])
        return CVReadOnlyPixelBuffer(unsafeBuffer: pixels)
    }

    private func silence(frame index: Int) throws -> CMReadySampleBuffer<CMSampleBuffer.DynamicContent> {
        let rate = 44100
        let count = rate / framesPerSecond
        var format = AudioStreamBasicDescription(
            mSampleRate: Double(rate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 2,
            mFramesPerPacket: 1,
            mBytesPerFrame: 2,
            mChannelsPerFrame: 1,
            mBitsPerChannel: 16,
            mReserved: 0,
        )
        var description: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: nil,
            asbd: &format,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &description,
        )
        var block: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(
            allocator: nil,
            memoryBlock: nil,
            blockLength: count * 2,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: count * 2,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &block,
        )
        let data = try #require(block)
        CMBlockBufferFillDataBytes(with: 0, blockBuffer: data, offsetIntoDestination: 0, dataLength: count * 2)
        var sample: CMSampleBuffer?
        CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: nil,
            dataBuffer: data,
            formatDescription: try #require(description),
            sampleCount: count,
            presentationTimeStamp: CMTime(value: CMTimeValue(index * count), timescale: CMTimeScale(rate)),
            packetDescriptions: nil,
            sampleBufferOut: &sample,
        )
        return try CMReadySampleBuffer(unsafeBuffer: #require(sample))
    }
}
