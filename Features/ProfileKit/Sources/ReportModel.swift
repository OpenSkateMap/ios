import FactoryKit
import Observation
import PeopleKit

@MainActor
@Observable
final class ReportModel {

    // MARK: Static Properties

    static let messageLimit = 500

    // MARK: Computed Properties

    var canSend: Bool {
        reason != nil && !isSending && message.count <= Self.messageLimit
    }

    // MARK: Properties

    let target: Report.Target
    let reasons: [Report.Reason]
    var reason: Report.Reason?
    var message = ""
    private(set) var isSending = false

    @ObservationIgnored @Injected(\.profileSession) private var profileSession

    // MARK: Lifecycle

    init(target: Report.Target) {
        self.target = target
        reasons = Report.Reason.offered(for: target)
    }

    // MARK: Functions

    func send() async throws {
        guard let reason, canSend else {
            return
        }
        isSending = true
        defer { isSending = false }
        try await profileSession.report(Report(target: target, reason: reason, message: message))
    }
}
