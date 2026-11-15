public import UIKit

extension UIBarButtonItem {
    public static func spinner() -> UIBarButtonItem {
        UIBarButtonItem(customView: UIActivityIndicatorView.spinning())
    }
}

extension UICellAccessory {
    public static func spinner() -> UICellAccessory {
        .customView(configuration: .init(customView: UIActivityIndicatorView.spinning(), placement: .trailing()))
    }
}

extension UIActivityIndicatorView {
    fileprivate static func spinning() -> UIActivityIndicatorView {
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.startAnimating()
        return spinner
    }
}
