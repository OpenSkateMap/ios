import ComponentKit
import PinLayout
import UIKit

/// Under a clip full screen: play or pause, where it is and what's left, and its sound when it has any.
final class ClipControlsView: UIVisualEffectView {

    // MARK: Types

    enum Sound {
        case none
        case on
        case off
    }

    // MARK: Static Properties

    static let height: CGFloat = 48

    private static let buttonSide: CGFloat = 44
    private static let gap: CGFloat = 8
    private static let timeFont = UIFontMetrics(forTextStyle: .footnote)
        .scaledFont(for: .monospacedDigitSystemFont(ofSize: 13, weight: .semibold))

    // MARK: Properties

    var onPlayPause: (() -> Void)?
    var onScrubStart: (() -> Void)?
    var onScrub: ((Double) -> Void)?
    var onScrubEnd: (() -> Void)?
    var onSoundToggle: (() -> Void)?

    private(set) var isScrubbing = false

    private let playButton = UIButton(configuration: .plain())
    private let soundButton = UIButton(configuration: .plain())
    private let slider = UISlider()
    private let elapsedLabel = Label()
    private let remainingLabel = Label()
    private var duration: Double = 0
    private var timeWidth: CGFloat = 0

    // MARK: Lifecycle

    init() {
        super.init(effect: UIGlassEffect())

        cornerConfiguration = .capsule()
        for button in [playButton, soundButton] {
            button.configuration?.baseForegroundColor = .label
            button.configuration?.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
                textStyle: .body,
                scale: .medium,
            )
            button.configuration?.symbolContentTransition = UISymbolContentTransition(.replace)
            contentView.addSubview(button)
        }
        playButton.addAction(UIAction { [weak self] _ in self?.onPlayPause?() }, for: .primaryActionTriggered)
        soundButton.addAction(UIAction { [weak self] _ in self?.onSoundToggle?() }, for: .primaryActionTriggered)
        slider.sliderStyle = .thumbless
        slider.minimumTrackTintColor = .label
        slider.accessibilityLabel = SpotDetailKitStrings.PhotoViewer.A11y.position
        slider.addAction(UIAction { [weak self] _ in self?.scrubStarted() }, for: .touchDown)
        slider.addAction(UIAction { [weak self] _ in self?.scrubbed() }, for: .valueChanged)
        slider.addAction(UIAction { [weak self] _ in self?.scrubEnded() }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
        contentView.addSubview(slider)
        for label in [elapsedLabel, remainingLabel] {
            label.font = Self.timeFont
            label.adjustsFontForContentSizeCategory = true
            label.textColor = .secondaryLabel
            label.isAccessibilityElement = false
            contentView.addSubview(label)
        }
        elapsedLabel.textAlignment = .natural
        show(isPlaying: true)
        show(sound: .none)
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (view: Self, _) in
            view.measureTime()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        remainingLabel.textAlignment = traitCollection.trailingTextAlignment
        playButton.pin
            .vCenter()
            .start(2)
            .size(Self.buttonSide)
        if soundButton.isHidden {
            remainingLabel.pin
                .vCenter()
                .end(16)
                .width(timeWidth)
                .sizeToFit(.width)
        } else {
            soundButton.pin
                .vCenter()
                .end(2)
                .size(Self.buttonSide)
            remainingLabel.pin
                .vCenter()
                .before(of: soundButton)
                .width(timeWidth)
                .sizeToFit(.width)
        }
        elapsedLabel.pin
            .vCenter()
            .after(of: playButton)
            .width(timeWidth)
            .sizeToFit(.width)
        slider.pin
            .vCenter()
            .horizontallyBetween(elapsedLabel, and: remainingLabel)
            .marginHorizontal(Self.gap)
            .sizeToFit(.width)
    }

    // MARK: Static Functions

    private static func time(_ seconds: Double) -> String {
        Duration.seconds(max(0, seconds)).formatted(.time(pattern: .minuteSecond))
    }

    // MARK: Functions

    func show(duration: Double) {
        self.duration = duration
        slider.maximumValue = Float(duration)
        measureTime()
        show(position: 0)
    }

    func show(position: Double) {
        guard !isScrubbing else {
            return
        }
        slider.value = Float(min(max(position, 0), duration))
        showTimes()
    }

    func show(isPlaying: Bool) {
        playButton.configuration?.image = UIImage(systemName: isPlaying ? "pause.fill" : "play.fill")
        playButton.accessibilityLabel = isPlaying
            ? SpotDetailKitStrings.PhotoViewer.A11y.pause
            : SpotDetailKitStrings.PhotoViewer.A11y.play
    }

    func show(sound: Sound) {
        soundButton.isHidden = sound == .none
        soundButton.configuration?.image = UIImage(systemName: sound == .off ? "speaker.slash.fill" : "speaker.wave.2.fill")
        soundButton.accessibilityLabel = sound == .off
            ? SpotDetailKitStrings.PhotoViewer.A11y.unmute
            : SpotDetailKitStrings.PhotoViewer.A11y.mute
        setNeedsLayout()
    }

    /// Both times as wide as the longest either can be, so the scrubber never shifts as they count.
    private func measureTime() {
        elapsedLabel.text = "-" + Self.time(duration)
        timeWidth = ceil(elapsedLabel.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: Self.height)).width)
        showTimes()
        setNeedsLayout()
    }

    private func showTimes() {
        let position = Double(slider.value)
        elapsedLabel.text = Self.time(position.rounded(.down))
        remainingLabel.text = "-" + Self.time((duration - position).rounded(.up))
        slider.accessibilityValue = SpotDetailKitStrings.PhotoViewer.A11y.positionValue(
            Self.time(position.rounded(.down)),
            Self.time(duration.rounded()),
        )
    }

    private func scrubStarted() {
        isScrubbing = true
        onScrubStart?()
    }

    private func scrubbed() {
        showTimes()
        onScrub?(Double(slider.value))
    }

    private func scrubEnded() {
        isScrubbing = false
        onScrubEnd?()
    }
}
