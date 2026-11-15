import UIKit

/// The Home Screen's editing jiggle: three autoreversing animations on a layer, each from a random phase, so
/// neighbours never move in step.
enum Jiggle {

    // MARK: Types

    private enum Track: CaseIterable {
        case translationX
        case translationY
        case rotation

        // MARK: Computed Properties

        var key: String {
            switch self {
            case .translationX: "jiggle.x"
            case .translationY: "jiggle.y"
            case .rotation: "jiggle.rotation"
            }
        }

        var keyPath: String {
            switch self {
            case .translationX: "transform.translation.x"
            case .translationY: "transform.translation.y"
            case .rotation: "transform.rotation"
            }
        }

        /// The Home Screen's periods: close but unequal, so the motion never repeats exactly.
        var duration: CFTimeInterval {
            switch self {
            case .translationX: 0.134
            case .translationY: 0.142
            case .rotation: 0.128
            }
        }
    }

    // MARK: Static Properties

    private static let translation = 0.4
    /// Radians for an icon-sized item; larger items turn less, as a widget does.
    private static let rotation = 0.03
    private static let iconSide: CGFloat = 79
    private static let timing = CAMediaTimingFunction(controlPoints: 0.36, 0, 0.63, 1)

    // MARK: Static Functions

    static func isJiggling(_ layer: CALayer) -> Bool {
        layer.animation(forKey: Track.rotation.key) != nil
    }

    static func start(on layer: CALayer, side: CGFloat) {
        guard !UIAccessibility.isReduceMotionEnabled else {
            stop(on: layer)
            return
        }
        guard !isJiggling(layer) else {
            return
        }
        let rotation = rotation / max(1, (side / iconSide).rounded())
        for track in Track.allCases {
            let amount = track == .rotation ? rotation : translation
            let animation = CABasicAnimation(keyPath: track.keyPath)
            animation.fromValue = -amount
            animation.toValue = amount
            animation.duration = track.duration
            // A begin time in the past: a random phase, not a delay.
            animation.beginTime = Double.random(in: 0..<1)
            animation.timingFunction = timing
            animation.autoreverses = true
            animation.repeatCount = .infinity
            animation.isRemovedOnCompletion = false
            layer.add(animation, forKey: track.key)
        }
    }

    /// Eases from wherever the jiggle is back to rest.
    static func stop(on layer: CALayer) {
        for track in Track.allCases where layer.animation(forKey: track.key) != nil {
            let settle = CABasicAnimation(keyPath: track.keyPath)
            settle.duration = 0.3
            settle.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(settle, forKey: track.key + ".settle")
            layer.removeAnimation(forKey: track.key)
        }
    }
}
