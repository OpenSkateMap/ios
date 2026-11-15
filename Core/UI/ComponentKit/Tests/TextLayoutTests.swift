import Testing
import UIKit
@testable import ComponentKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct TextLayoutTests {
    private let font = UIFont.systemFont(ofSize: 17)

    @Test
    func `a one-line label grows back to its whole text, as UILabel does`() {
        let label = Label()
        label.font = font
        label.text = "43"
        label.frame.size = label.sizeThatFits(.zero)
        label.text = "Plaça Joan Coromines"

        let grown = label.sizeThatFits(label.bounds.size)

        #expect(grown.width == label.textLayout.size(fitting: 0).width)
        #expect(grown.width > label.bounds.width)
    }

    @Test
    func `a label sized by its layout draws its whole text`() throws {
        let descriptor = try #require(UIFont.systemFont(ofSize: 15, weight: .bold).fontDescriptor.withDesign(.rounded))
        let label = Label()
        label.font = UIFont(descriptor: descriptor, size: 15)
        label.textAlignment = .center
        let clipped = (0...100).map(String.init).filter { score in
            label.text = score
            let fitted = label.sizeThatFits(CGSize(width: 300, height: CGFloat.greatestFiniteMagnitude))
            let needed = label.textRect(forBounds: CGRect(x: 0, y: 0, width: 1000, height: 100), limitedToNumberOfLines: 1)
            return fitted.width < needed.width
        }

        #expect(clipped.isEmpty)
    }

    @Test
    func `runs without a font measure in the label's font, as UILabel draws them`() throws {
        let label = Label()
        label.numberOfLines = 0
        let text = NSMutableAttributedString(attachment: NSTextAttachment(image: try #require(UIImage(systemName: "star.fill"))))
        text.append(NSAttributedString(string: " "))
        text.append(NSAttributedString(
            string: "Already on the map:\nWell Ledges — 90 m\nSouthbank Undercroft — 90 m",
            attributes: [.font: UIFont.preferredFont(forTextStyle: .subheadline)],
        ))
        label.attributedText = text

        let fitted = label.sizeThatFits(CGSize(width: 340, height: CGFloat.greatestFiniteMagnitude))
        let drawn = label.textRect(forBounds: CGRect(x: 0, y: 0, width: 340, height: 1000), limitedToNumberOfLines: 0)

        #expect(fitted.height >= drawn.height)
    }

    @Test
    func `one line is the font's line height, rounded up`() {
        let size = layout("MACBA").size(fitting: 300)

        #expect(size.height == ceil(font.lineHeight))
        #expect(size.width > 0 && size.width <= 300)
    }

    @Test
    func `long text wraps, and the line limit stops it`() {
        let text = String(repeating: "Ledges, banks and the four-stair gap. ", count: 8)

        let free = layout(text).size(fitting: 200)
        let two = layout(text, lines: 2).size(fitting: 200)

        #expect(free.height > ceil(font.lineHeight * 3))
        #expect(two.height == ceil(font.lineHeight * 2))
    }

    @Test
    func `a truncating paragraph style still wraps up to the limit`() {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let text = NSAttributedString(
            string: String(repeating: "Plaça Joan Coromines ", count: 10),
            attributes: [.font: font, .paragraphStyle: style],
        )

        let size = TextLayout(text: text, numberOfLines: 3).size(fitting: 200)

        #expect(size.height == ceil(font.lineHeight * 3))
    }

    @Test
    func `empty text takes no room`() {
        #expect(layout("").size(fitting: 200) == .zero)
    }

    @Test
    func `a label measures with its text layout and keeps the size until the text changes`() {
        let label = Label()
        label.font = font
        label.numberOfLines = 0
        label.text = "Universitat"
        let expected = label.textLayout.size(fitting: 200)

        let short = label.sizeThatFits(CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude))
        label.text = String(repeating: "Universitat ", count: 20)
        let long = label.sizeThatFits(CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude))

        #expect(short == expected)
        #expect(long.height > short.height)
    }

    @Test
    func `at accessibility sizes a label reads back the accessibility line limit, and its own one after`() {
        let label = Label()
        label.numberOfLines = 2
        label.linesAtAccessibilitySizes = 0

        label.traitOverrides.preferredContentSizeCategory = .accessibilityLarge
        label.updateTraitsIfNeeded()
        let atAccessibilitySize = label.numberOfLines
        label.numberOfLines = 3
        let setAtAccessibilitySize = label.numberOfLines
        label.traitOverrides.preferredContentSizeCategory = .large
        label.updateTraitsIfNeeded()

        #expect(atAccessibilitySize == 0)
        #expect(setAtAccessibilitySize == 0)
        #expect(label.numberOfLines == 3)
    }

    private func layout(_ string: String, lines: Int = 0) -> TextLayout {
        TextLayout(text: NSAttributedString(string: string, attributes: [.font: font]), numberOfLines: lines)
    }

}
