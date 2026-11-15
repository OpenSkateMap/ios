import ObjectiveC
import os
import SwiftMacros
import UIKit

final class RegulatedCollectionView: UICollectionView {

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "map")

    private static let hooksInstalled: Bool = installHooks()

    // MARK: Properties

    weak var regulator: any ScrollRegulator?

    // MARK: Lifecycle

    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        _ = Self.hooksInstalled
        super.init(frame: frame, collectionViewLayout: layout)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    /// The top inset belongs to the header over it: a drag there moves the panel, and taps don't reach rows under it.
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        point.y >= bounds.minY + adjustedContentInset.top && super.point(inside: point, with: event)
    }

    // MARK: Static Functions

    private static func installHooks() -> Bool {
        let panSelector = NSSelectorFromString(#Obfuscate("handlePan:"))
        let endSelector = NSSelectorFromString(#Obfuscate("_scrollViewWillEndDraggingWithDeceleration:"))
        // `void handlePan:(UIPanGestureRecognizer *)` and `BOOL …WithDeceleration:(BOOL)`, as of iOS 27.
        let panEncoding = "v24@0:8@16"
        let endEncoding = "B20@0:8B16"
        guard let panMethod = class_getInstanceMethod(UICollectionView.self, panSelector),
              let endMethod = class_getInstanceMethod(UICollectionView.self, endSelector),
              encoding(of: panMethod) == panEncoding,
              encoding(of: endMethod) == endEncoding else {
            logger.notice("Scroll regulation isn't available; lists scroll on their own")
            return false
        }

        typealias Pan = @convention(c) (UIScrollView, Selector, UIPanGestureRecognizer) -> Void
        let handlePan = unsafeBitCast(method_getImplementation(panMethod), to: Pan.self)
        let regulatedPan: @convention(block) (UIScrollView, UIPanGestureRecognizer) -> Void = { scrollView, pan in
            let previous = scrollView.contentOffset
            handlePan(scrollView, panSelector, pan)
            MainActor.assumeIsolated {
                guard let regulator = (scrollView as? RegulatedCollectionView)?.regulator else {
                    return
                }
                let proposed = scrollView.contentOffset
                let kept = regulator.scrollView(scrollView, regulating: proposed, from: previous, pan: pan)
                if kept != proposed {
                    scrollView.contentOffset = kept
                }
            }
        }

        typealias End = @convention(c) (UIScrollView, Selector, Bool) -> Bool
        let willEnd = unsafeBitCast(method_getImplementation(endMethod), to: End.self)
        let regulatedEnd: @convention(block) (UIScrollView, Bool) -> Bool = { scrollView, deceleration in
            let decelerates = willEnd(scrollView, endSelector, deceleration)
            return MainActor.assumeIsolated {
                guard let regulator = (scrollView as? RegulatedCollectionView)?.regulator else {
                    return decelerates
                }
                return regulator.scrollView(scrollView, shouldDecelerate: decelerates)
            }
        }

        class_addMethod(self, panSelector, imp_implementationWithBlock(regulatedPan), panEncoding)
        class_addMethod(self, endSelector, imp_implementationWithBlock(regulatedEnd), endEncoding)
        return true
    }

    private static func encoding(of method: Method) -> String? {
        method_getTypeEncoding(method).map { String(cString: $0) }
    }
}
