import ObjectiveC
import SwiftMacros
public import UIKit

// MARK: - ConfettiView

/// A celebration for a rare moment: a burst of paper from the centre of the view that earned it, over the whole window,
/// with a success haptic. It pops, hangs, flutters and falls through Core Animation's private emitter behaviours
/// (attractor, drag, wave), on two layers for depth, and removes itself after 3 s. It takes no touch and is hidden from
/// VoiceOver, which hears the headline instead. With Reduce Motion, or when the private behaviours aren't there, it's
/// the haptic alone: never the flat public-only look.
public final class ConfettiView: UIView {

    // MARK: Types

    /// Every number the burst is made of, so retuning it changes only this.
    enum Tuning {

        // MARK: Static Properties

        static let duration: CFTimeInterval = 3
        static let fadeStart: CFTimeInterval = 2.5
        static let birthRateRamp: CFTimeInterval = 0.3
        static let sourceSize = CGSize(width: 40, height: 40)
        /// Births per second of each cell on the front layer, before the colour's weight; the back layer has half.
        static let frontBirthRate: Float = 55
        static let backBirthRate: Float = 27
        static let backScale: CGFloat = 0.5
        static let backOpacity: Float = 0.5
        static let backSpeed: Float = 0.95
        static let rectangle = CGSize(width: 10, height: 6.5)
        static let rectangleCorner: CGFloat = 1
        static let circle: CGFloat = 5
        static let lifetime: Float = 3.5
        static let lifetimeRange: Float = 0.5
        static let spin: CGFloat = 4
        static let spinRange: CGFloat = 8
        static let scaleRange: CGFloat = 0.25
        static let alphaSpeed: Float = -0.2
        static let attractorFalloff = -290
        static let attractorRadius = 300
        static let attractorStiffness: [Double] = [80, 5]
        static let attractorStiffnessTimes: [Double] = [0, 0.4]
        static let attractorZPosition = -70
        /// Below the source, so the pop leans upward.
        static let attractorOffset: CGFloat = 20
        static let drag: (to: Double, over: CFTimeInterval) = (2, 0.35)
        static let horizontalWave: (force: [Double], frequency: Double) = ([100, 0, 0], 0.5)
        static let verticalWave: (force: [Double], frequency: Double) = ([0, 500, 0], 3)
        static let gravity: (values: [Double], times: [Double], duration: CFTimeInterval) = (
            [0, 300, 750, 1000],
            [0.05, 0.1, 0.5, 1],
            6,
        )

        // MARK: Static Functions

        /// The brand three, the main orange twice as often, and two neutrals that read on the appearance.
        static func colors(for style: UIUserInterfaceStyle) -> [(color: UIColor, weight: Float)] {
            let neutrals = style == .dark ? [0xF2EFEA, 0x8C8C8C] : [0x1A1A1A, 0xD9D4CC]
            return [(.brand, 2), (UIColor(hex: 0xFF8A4C), 1), (UIColor(hex: 0xC23F06), 1)]
                + neutrals.map { (UIColor(hex: $0), 1) }
        }
    }

    /// The private emitter behaviours, found once; nil when this system doesn't have them as expected.
    private struct Behaviors {
        typealias Make = @convention(c) (AnyClass, Selector, NSString) -> NSObject?

        static let available = Behaviors()

        let behaviorClass: AnyClass
        let selector: Selector
        let make: Make

        private init?() {
            let selector = NSSelectorFromString(#Obfuscate("behaviorWithType:"))
            let setter = NSSelectorFromString(#Obfuscate("setEmitterBehaviors:"))
            // `+ (instancetype)behaviorWithType:(NSString *)` and `- (void)setEmitterBehaviors:(NSArray *)`, as of iOS 27.
            guard let behaviorClass = NSClassFromString(#Obfuscate("CAEmitterBehavior")),
                  let method = class_getClassMethod(behaviorClass, selector),
                  method_getTypeEncoding(method).map({ String(cString: $0) }) == "@24@0:8@16",
                  let setterMethod = class_getInstanceMethod(CAEmitterLayer.self, setter),
                  method_getTypeEncoding(setterMethod).map({ String(cString: $0) }) == "v24@0:8@16" else {
                return nil
            }
            self.behaviorClass = behaviorClass
            self.selector = selector
            make = unsafeBitCast(method_getImplementation(method), to: Make.self)
        }

        func behavior(_ type: String, name: String, values: [String: Any]) -> NSObject? {
            guard let behavior = make(behaviorClass, selector, type as NSString) else {
                return nil
            }
            behavior.setValue(name, forKey: "name")
            for (key, value) in values {
                behavior.setValue(value, forKey: key)
            }
            return behavior
        }
    }

    // MARK: Static Properties

    private static let behaviorsKey = #Obfuscate("emitterBehaviors")

    // MARK: Properties

    private let front = CAEmitterLayer()
    private let back = CAEmitterLayer()

    // MARK: Lifecycle

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        layer.addSublayer(back)
        layer.addSublayer(front)
    }

    // MARK: Static Functions

    /// Bursts from the centre of `element` over its window, plays the success haptic and tells VoiceOver `headline`.
    public static func burst(from element: UIView, announcing headline: String? = nil) {
        let haptic = UINotificationFeedbackGenerator(view: element)
        haptic.prepare()
        if let headline {
            UIAccessibility.post(notification: .announcement, argument: headline)
        }
        defer { haptic.notificationOccurred(.success) }
        guard !UIAccessibility.isReduceMotionEnabled, let behaviors = Behaviors.available, let window = element.window else {
            return
        }
        let confetti = ConfettiView(frame: window.bounds)
        window.addSubview(confetti)
        confetti.start(
            at: element.convert(CGPoint(x: element.bounds.midX, y: element.bounds.midY), to: window),
            colors: Tuning.colors(for: window.traitCollection.userInterfaceStyle),
            scale: window.traitCollection.displayScale,
            behaviors: behaviors,
        )
    }

    /// White, so each cell's `color` tints it.
    private static func shapes(scale: CGFloat) -> [(name: String, image: CGImage)] {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let rectangle = UIGraphicsImageRenderer(size: Tuning.rectangle, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: Tuning.rectangle), cornerRadius: Tuning.rectangleCorner).fill()
        }
        let side = CGSize(width: Tuning.circle, height: Tuning.circle)
        let circle = UIGraphicsImageRenderer(size: side, format: format).image { _ in
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(origin: .zero, size: side)).fill()
        }
        return [("rectangle", rectangle.cgImage), ("circle", circle.cgImage)].compactMap { name, image in
            image.map { (name, $0) }
        }
    }

    private static func cells(colors: [(color: UIColor, weight: Float)],
                              shapes: [(name: String, image: CGImage)],
                              scale: CGFloat,
                              birthRate: Float,
                              particleScale: CGFloat) -> [CAEmitterCell] {
        let averageWeight = colors.map(\.weight).reduce(0, +) / Float(max(colors.count, 1))
        return shapes.flatMap { shape in
            colors.enumerated().map { index, entry in
                let cell = CAEmitterCell()
                cell.name = "\(shape.name)\(index)"
                cell.contents = shape.image
                cell.contentsScale = scale
                cell.color = entry.color.cgColor
                cell.birthRate = birthRate * entry.weight / averageWeight
                cell.lifetime = Tuning.lifetime
                cell.lifetimeRange = Tuning.lifetimeRange
                cell.velocity = 0
                cell.emissionRange = .pi * 2
                cell.spin = Tuning.spin
                cell.spinRange = Tuning.spinRange
                cell.scale = particleScale
                cell.scaleRange = Tuning.scaleRange * particleScale
                cell.alphaSpeed = Tuning.alphaSpeed
                return cell
            }
        }
    }

    // MARK: Functions

    private func start(at origin: CGPoint,
                       colors: [(color: UIColor, weight: Float)],
                       scale: CGFloat,
                       behaviors: Behaviors) {
        let shapes = Self.shapes(scale: scale)
        let now = CACurrentMediaTime()
        for (emitter, isBack) in [(front, false), (back, true)] {
            emitter.frame = bounds
            emitter.emitterPosition = origin
            emitter.emitterShape = .sphere
            emitter.emitterSize = Tuning.sourceSize
            emitter.emitterCells = Self.cells(
                colors: colors,
                shapes: shapes,
                scale: scale,
                birthRate: isBack ? Tuning.backBirthRate : Tuning.frontBirthRate,
                particleScale: isBack ? Tuning.backScale : 1,
            )
            emitter.setValue(behaviorObjects(at: origin, behaviors: behaviors), forKey: Self.behaviorsKey)
            if isBack {
                emitter.opacity = Tuning.backOpacity
                emitter.speed = Tuning.backSpeed
            }
            // Without it the emitter simulates from the layer's time origin and starts with pieces already mid-air.
            emitter.beginTime = now
            emitter.birthRate = 0
            addAnimations(to: emitter)
        }
        let fade = CAKeyframeAnimation(keyPath: #keyPath(CALayer.opacity))
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, NSNumber(value: Tuning.fadeStart / Tuning.duration), 1]
        fade.duration = Tuning.duration
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.removeFromSuperview()
        }
        layer.opacity = 0
        layer.add(fade, forKey: "fade")
        CATransaction.commit()
    }

    private func behaviorObjects(at origin: CGPoint, behaviors: Behaviors) -> [NSObject] {
        [
            behaviors.behavior("attractor", name: "attractor", values: [
                "falloff": Tuning.attractorFalloff,
                "radius": Tuning.attractorRadius,
                "stiffness": Tuning.attractorStiffness.last ?? 0,
                "position": NSValue(cgPoint: CGPoint(x: origin.x, y: origin.y + Tuning.attractorOffset)),
                "zPosition": Tuning.attractorZPosition,
            ]),
            behaviors.behavior("drag", name: "drag", values: ["drag": Tuning.drag.to]),
            behaviors.behavior("wave", name: "horizontalWave", values: [
                "force": Tuning.horizontalWave.force,
                "frequency": Tuning.horizontalWave.frequency,
            ]),
            behaviors.behavior("wave", name: "verticalWave", values: [
                "force": Tuning.verticalWave.force,
                "frequency": Tuning.verticalWave.frequency,
            ]),
        ].compactMap(\.self)
    }

    private func addAnimations(to emitter: CAEmitterLayer) {
        let birthRate = CABasicAnimation(keyPath: #keyPath(CAEmitterLayer.birthRate))
        birthRate.fromValue = 1
        birthRate.toValue = 0
        birthRate.duration = Tuning.birthRateRamp
        emitter.add(birthRate, forKey: "birthRate")

        let stiffness = CAKeyframeAnimation(keyPath: "\(Self.behaviorsKey).attractor.stiffness")
        stiffness.values = Tuning.attractorStiffness
        stiffness.keyTimes = Tuning.attractorStiffnessTimes.map { NSNumber(value: $0) }
        stiffness.timingFunction = CAMediaTimingFunction(name: .easeOut)
        stiffness.duration = Tuning.duration
        emitter.add(stiffness, forKey: "stiffness")

        let drag = CABasicAnimation(keyPath: "\(Self.behaviorsKey).drag.drag")
        drag.fromValue = 0
        drag.toValue = Tuning.drag.to
        drag.duration = Tuning.drag.over
        emitter.add(drag, forKey: "drag")

        for cell in emitter.emitterCells ?? [] {
            guard let name = cell.name else {
                continue
            }
            let gravity = CAKeyframeAnimation(keyPath: "emitterCells.\(name).yAcceleration")
            gravity.values = Tuning.gravity.values
            gravity.keyTimes = Tuning.gravity.times.map { NSNumber(value: $0) }
            gravity.duration = Tuning.gravity.duration
            emitter.add(gravity, forKey: "gravity.\(name)")
        }
    }
}

extension UIColor {
    fileprivate convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1,
        )
    }
}
