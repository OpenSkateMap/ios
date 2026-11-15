import Foundation
import Testing
@testable import ProfileKit

@Suite(.timeLimit(.minutes(1)))
struct FeedbackMailTests {
    @Test
    func `the log attachment is never empty, so Mail always attaches it`() async {
        let log = String(decoding: await FeedbackMail.runLog(), as: UTF8.self)

        let firstLine = log.split(separator: "\n").first.map(String.init) ?? ""
        #expect(firstLine.hasPrefix("OpenSkateMap log since launch at "))
        #expect(!firstLine.hasSuffix("an unknown time"))
        #expect(log.split(separator: "\n").count >= 2)
    }
}
