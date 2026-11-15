public import SpotsKit
public import UIKit

public struct SpotSheet {
    public let make: (SpotSelection) -> UIViewController
    public let lowestDetentHeight: CGFloat

    public init(lowestDetentHeight: CGFloat, make: @escaping (SpotSelection) -> UIViewController) {
        self.make = make
        self.lowestDetentHeight = lowestDetentHeight
    }
}
