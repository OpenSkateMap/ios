// Lint fixture, never compiled: `mise run ios:lint` checks that each rule still flags the line after
// an `// expect:` comment and nothing else. See FixtureCell.swift for the convention.

func physicalEdges(view: UIView, other: UIView) {
    view.pin
        .top()
        // expect: pinlayout_left_right
        .left(16)
        // expect: pinlayout_left_right
        .right()
        // expect: pinlayout_left_right
        .marginLeft(8)
        // expect: pinlayout_left_right
        .marginRight(8)
    view.pin
        // expect: pinlayout_left_right
        .left(of: other, aligned: .center)
        // expect: pinlayout_left_right
        .bottomRight(to: other.anchor.bottomStart)
    view.pin
        // expect: pinlayout_left_right
        .below(of: other, aligned: .left)
        // expect: pinlayout_left_right
        .start(to: other.edge.right)
    view.pin
        // expect: pinlayout_left_right
        .topStart(to: other.anchor.topLeft)
    // expect: pinlayout_left_right
    view.pin.top(8).left(16).size(24)
}

func physicalTextAlignments(label: UILabel) {
    // expect: pinlayout_left_right
    label.textAlignment = .left
    // expect: pinlayout_left_right
    label.textAlignment = .right
    // expect: pinlayout_left_right
    label.textAlignment=.right
}

func directionalEdges(view: UIView, other: UIView, insets: UIEdgeInsets, label: UILabel) {
    view.pin
        .top()
        .start(insets)
        .end(to: other.edge.start)
        .marginStart(8)
        .marginEnd(insets.right)
    view.pin
        .below(of: other, aligned: .start)
        .bottomEnd(to: other.anchor.bottomEnd)
    view.pin.top(8).start(16).size(24)
    // view.pin.left() in a comment stays silent
    let text = ".left( in a string"
    let corners: UIRectCorner = [.topLeft, .topRight]
    let inset = insets.left + insets.right
    outbox.left(entries: [], photos: [])
    label.textAlignment = .natural
    label.textAlignment = label.traitCollection.trailingTextAlignment
    let alignment: NSTextAlignment = label.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .left : .right
    // swiftlint:disable pinlayout_left_right - fixture for a documented physical placement
    view.pin
        .top()
        .left(inset)
    // swiftlint:enable pinlayout_left_right
}
