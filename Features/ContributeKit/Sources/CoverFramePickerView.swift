import AVFoundation
import ComponentKit
import PinLayout
import UIKit

// MARK: - CoverFramePickerView

/// The Cover Frame sheet's content: the chosen frame large, over a strip of frames along the clip with a selection to
/// drag. Dragging shows the nearest frame that decodes fast; letting go, or a tap, shows the exact one, which is the
/// frame the poster is made from. The strip runs in the reading direction, as a slider does.
final class CoverFramePickerView: UIView {

    // MARK: Static Properties

    private static let frameCount = 9
    private static let stripHeight: CGFloat = 52
    /// The selection stands out of the strip by this much above and below.
    private static let selectionOverhang: CGFloat = 4
    private static let frameCornerRadius: CGFloat = 28
    private static let stripCornerRadius: CGFloat = 8

    // MARK: Computed Properties

    private var isRightToLeft: Bool {
        effectiveUserInterfaceLayoutDirection == .rightToLeft
    }

    // MARK: Properties

    /// Seconds into the clip.
    private(set) var time: Double = 0

    private let duration: Double
    private let displaySize: CGSize
    private let frameView = UIImageView()
    private let strip = UIView()
    private let selection = UIImageView()
    private var thumbnails = [UIImageView]()
    private let thumbnailGenerator: AVAssetImageGenerator
    private let scrubGenerator: AVAssetImageGenerator
    private let exactGenerator: AVAssetImageGenerator
    private var pendingFrame: (time: Double, isExact: Bool)?
    private var generatingFrame: Task<Void, Never>?
    private var loadingThumbnails: Task<Void, Never>?

    // MARK: Lifecycle

    /// `duration` is how much of `file` the clip covers, from its start; `displaySize` the video's upright size.
    init(file: URL, duration: Double, displaySize: CGSize) {
        self.duration = duration
        self.displaySize = displaySize
        let asset = AVURLAsset(url: file)
        thumbnailGenerator = Self.generator(for: asset, maximumSide: 200, tolerance: CMTime(seconds: 0.5, preferredTimescale: 600))
        scrubGenerator = Self.generator(for: asset, maximumSide: 1200, tolerance: CMTime(seconds: 0.15, preferredTimescale: 600))
        exactGenerator = Self.generator(for: asset, maximumSide: 1200, tolerance: .zero)
        super.init(frame: .zero)

        frameView.contentMode = .scaleAspectFill
        frameView.backgroundColor = .tertiarySystemFill
        frameView.layer.cornerRadius = Self.frameCornerRadius
        frameView.layer.cornerCurve = .continuous
        frameView.clipsToBounds = true
        frameView.accessibilityIgnoresInvertColors = true
        strip.backgroundColor = .tertiarySystemFill
        strip.layer.cornerRadius = Self.stripCornerRadius
        strip.layer.cornerCurve = .continuous
        strip.clipsToBounds = true
        thumbnails = (0..<Self.frameCount).map { _ in
            let view = UIImageView()
            view.contentMode = .scaleAspectFill
            view.clipsToBounds = true
            strip.addSubview(view)
            return view
        }
        selection.contentMode = .scaleAspectFill
        selection.clipsToBounds = true
        selection.layer.cornerRadius = 6
        selection.layer.cornerCurve = .continuous
        selection.layer.borderWidth = 3
        selection.layer.borderColor = UIColor.white.cgColor
        selection.backgroundColor = .secondarySystemFill
        for view in [frameView, strip, selection] {
            addSubview(view)
        }
        setupAccessibility()
        setupGestures()
        loadThumbnails()
        showFrame(at: 0, isExact: true)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        generatingFrame?.cancel()
        loadingThumbnails?.cancel()
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    override func accessibilityIncrement() {
        choose(time + duration / 10)
    }

    override func accessibilityDecrement() {
        choose(time - duration / 10)
    }

    // MARK: Static Functions

    private static func generator(for asset: AVAsset, maximumSide: CGFloat, tolerance: CMTime) -> AVAssetImageGenerator {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maximumSide, height: maximumSide)
        generator.requestedTimeToleranceBefore = tolerance
        generator.requestedTimeToleranceAfter = tolerance
        return generator
    }

    // MARK: Functions

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        let box = CGSize(width: width, height: min(width, 360))
        let aspect = displaySize.width > 0 && displaySize.height > 0 ? displaySize.width / displaySize.height : 16 / 9
        let fitted = aspect > box.width / box.height
            ? CGSize(width: box.width, height: (box.width / aspect).rounded())
            : CGSize(width: (box.height * aspect).rounded(), height: box.height)
        frameView.pin
            .top()
            .hCenter()
            .size(fitted)
        strip.pin
            .below(of: frameView)
            .start()
            .width(width)
            .height(Self.stripHeight)
            .marginTop(20 + Self.selectionOverhang)
        let thumbnailWidth = width / CGFloat(Self.frameCount)
        for (index, thumbnail) in thumbnails.enumerated() {
            thumbnail.pin
                .top()
                .start(CGFloat(index) * thumbnailWidth)
                .width(thumbnailWidth.rounded(.up))
                .height(Self.stripHeight)
        }
        let selectionSize = CGSize(width: max(thumbnailWidth, 32) + 8, height: Self.stripHeight + Self.selectionOverhang * 2)
        let travel = max(width - selectionSize.width, 0)
        let progress = duration > 0 ? time / duration : 0
        selection.pin
            .top(strip.frame.minY - Self.selectionOverhang)
            .start((travel * progress).rounded())
            .size(selectionSize)
        return strip.frame.maxY + Self.selectionOverhang
    }

    private func setupAccessibility() {
        isAccessibilityElement = true
        accessibilityTraits = .adjustable
        accessibilityLabel = ContributeKitStrings.NewSpot.CoverFrame.A11y.frame
        updateAccessibilityValue()
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(dragged(_:)))
        pan.delegate = self
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        for recognizer in [pan, tap] {
            addGestureRecognizer(recognizer)
        }
    }

    private func updateAccessibilityValue() {
        accessibilityValue = ContributeKitStrings.NewSpot.CoverFrame.A11y.position(
            ClipBadgeView.lengthText(milliseconds: Int((time * 1000).rounded())),
            ClipBadgeView.lengthText(milliseconds: Int((duration * 1000).rounded())),
        )
    }

    /// The time under `x`, measured from the leading edge along the strip's travel.
    private func time(at x: CGFloat) -> Double {
        let width = strip.bounds.width
        let selectionWidth = selection.bounds.width
        let travel = max(width - selectionWidth, 1)
        let fromLeading = isRightToLeft ? width - x : x
        let progress = min(max((fromLeading - selectionWidth / 2) / travel, 0), 1)
        return Double(progress) * duration
    }

    private func move(to time: Double) {
        self.time = min(max(time, 0), duration)
        updateAccessibilityValue()
        setNeedsLayout()
    }

    private func choose(_ time: Double) {
        move(to: time)
        showFrame(at: self.time, isExact: true)
    }

    /// The newest frame asked for wins; one is decoded at a time.
    private func showFrame(at time: Double, isExact: Bool) {
        pendingFrame = (time, isExact)
        guard generatingFrame == nil else {
            return
        }
        generatingFrame = Task { [weak self] in
            while let self, let pending = pendingFrame {
                pendingFrame = nil
                let generator = pending.isExact ? exactGenerator : scrubGenerator
                let time = CMTime(seconds: pending.time, preferredTimescale: 600)
                guard let image = try? await generator.image(at: time).image,
                      !Task.isCancelled else {
                    continue
                }
                let frame = UIImage(cgImage: image)
                frameView.image = frame
                selection.image = frame
            }
            self?.generatingFrame = nil
        }
    }

    private func loadThumbnails() {
        let step = duration / Double(Self.frameCount)
        let times = (0..<Self.frameCount).map { CMTime(seconds: step * (Double($0) + 0.5), preferredTimescale: 600) }
        loadingThumbnails = Task { [weak self, thumbnailGenerator] in
            for await result in thumbnailGenerator.images(for: times) {
                guard let self, let image = try? result.image, let index = times.firstIndex(of: result.requestedTime) else {
                    continue
                }
                thumbnails[index].image = UIImage(cgImage: image)
            }
        }
    }
}

// MARK: Actions

extension CoverFramePickerView {
    @objc
    private func dragged(_ pan: UIPanGestureRecognizer) {
        let x = pan.location(in: strip).x
        switch pan.state {
        case .began, .changed:
            move(to: time(at: x))
            showFrame(at: time, isExact: false)

        case .ended, .cancelled:
            choose(time(at: x))

        default:
            break
        }
    }

    @objc
    private func tapped(_ tap: UITapGestureRecognizer) {
        choose(time(at: tap.location(in: strip).x))
    }
}

// MARK: UIGestureRecognizerDelegate

extension CoverFramePickerView: UIGestureRecognizerDelegate {
    /// A sideways drag along the strip scrubs; one that goes down is the sheet's.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer.location(in: self).y >= strip.frame.minY - Self.selectionOverhang else {
            return false
        }
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else {
            return true
        }
        let velocity = pan.velocity(in: self)
        return abs(velocity.x) > abs(velocity.y)
    }
}
