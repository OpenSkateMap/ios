import AccountKit
import Foundation
import MessageUI
import OSLog
import UIKit

enum FeedbackMail {

    // MARK: Static Properties

    static let address = "feedback@openskatemap.app"

    private static let subject = "OpenSkateMap Feedback"
    private nonisolated static let subsystem = "com.ertembiyik.openskatemap"

    // MARK: Static Functions

    static func composer(account: Account?) async -> MFMailComposeViewController? {
        guard MFMailComposeViewController.canSendMail() else {
            return nil
        }
        let log = await runLog()
        let mail = MFMailComposeViewController()
        mail.setToRecipients([address])
        mail.setSubject(subject)
        mail.setMessageBody(body(account: account), isHTML: false)
        mail.addAttachmentData(log, mimeType: "text/plain", fileName: "OpenSkateMapLog.txt")
        return mail
    }

    static func mailtoURL(account: Account?) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body(account: account)),
        ]
        return components.url
    }

    @concurrent
    nonisolated static func runLog() async -> Data {
        let launch = launchDate()
        var lines = ["OpenSkateMap log since launch at \(launch?.formatted(.iso8601) ?? "an unknown time")"]
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let entries = try store.getEntries(
                at: launch.map { store.position(date: $0) } ?? store.position(timeIntervalSinceLatestBoot: 0),
                matching: NSPredicate(format: "subsystem == %@", subsystem),
            )
            lines += entries.compactMap { $0 as? OSLogEntryLog }.map { entry in
                "\(entry.date.formatted(.iso8601)) [\(entry.category)] \(entry.composedMessage)"
            }
            if lines.count == 1 {
                lines.append("Nothing logged.")
            }
        } catch {
            lines.append("The log couldn't be read: \(error.localizedDescription)")
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    private static func body(account: Account?) -> String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        let device = UIDevice.current
        let utc = Date.now.formatted(.iso8601.year().month().day().dateSeparator(.dash).time(includingFractionalSeconds: false))
        var lines = [
            "---",
            "Version: OpenSkateMap \(version) (\(build))",
            "System: \(device.systemName) \(device.systemVersion) on \(modelIdentifier())",
            "UTC Time: \(utc)",
            "Language/Region: \(Locale.current.identifier) - \(Locale.preferredLanguages.first ?? "?")",
            "Timezone: \(TimeZone.current.identifier)",
        ]
        if let account {
            lines.append("Account: \(account.id)")
        }
        lines.append("---")
        return "\n\n\n" + lines.joined(separator: "\n")
    }

    private static func modelIdentifier() -> String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }

    private nonisolated static func launchDate() -> Date? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var name = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&name, u_int(name.count), &info, &size, nil, 0) == 0 else {
            return nil
        }
        let start = info.kp_proc.p_un.__p_starttime
        return Date(timeIntervalSince1970: TimeInterval(start.tv_sec) + TimeInterval(start.tv_usec) / 1_000_000)
    }
}
