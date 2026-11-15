import ComponentKit
import UIKit

enum FormText {
    static func header(_ text: String) -> Label {
        let label = Label()
        label.text = text
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.accessibilityTraits = .header
        return label
    }

    static func hint(_ text: String) -> Label {
        let label = Label()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        return label
    }
}
