public import UIKit

extension UIViewController {
    public var topPresented: UIViewController {
        var top = self
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
