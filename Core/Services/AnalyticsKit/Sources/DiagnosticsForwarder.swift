import Darwin
import Foundation
import MetricKit

/// Hands MetricKit's crash, hang, CPU and disk-write exception and slow-launch diagnostics, delivered on a later
/// launch, to `send`.
final class DiagnosticsForwarder: NSObject, MXMetricManagerSubscriber, Sendable {

    // MARK: Static Properties

    private static let appBinary = Bundle.main.executableURL?.lastPathComponent ?? ProcessInfo.processInfo.processName

    private static let signalNames: [Int32: String] = [
        SIGABRT: "SIGABRT",
        SIGBUS: "SIGBUS",
        SIGFPE: "SIGFPE",
        SIGILL: "SIGILL",
        SIGKILL: "SIGKILL",
        SIGPIPE: "SIGPIPE",
        SIGSEGV: "SIGSEGV",
        SIGSYS: "SIGSYS",
        SIGTERM: "SIGTERM",
        SIGTRAP: "SIGTRAP",
    ]

    private static let machExceptionNames: [Int32: String] = [
        EXC_BAD_ACCESS: "EXC_BAD_ACCESS",
        EXC_BAD_INSTRUCTION: "EXC_BAD_INSTRUCTION",
        EXC_ARITHMETIC: "EXC_ARITHMETIC",
        EXC_SOFTWARE: "EXC_SOFTWARE",
        EXC_BREAKPOINT: "EXC_BREAKPOINT",
        EXC_CRASH: "EXC_CRASH",
        EXC_RESOURCE: "EXC_RESOURCE",
        EXC_GUARD: "EXC_GUARD",
    ]

    // MARK: Properties

    private let send: @Sendable (_ report: ExceptionReport, _ timestamp: Date) -> Void

    // MARK: Lifecycle

    init(send: @escaping @Sendable (_ report: ExceptionReport, _ timestamp: Date) -> Void) {
        self.send = send
    }

    // MARK: Static Functions

    static func report(_ crash: MXCrashDiagnostic) -> ExceptionReport {
        let signal = crash.signal.flatMap { signalNames[$0.int32Value] }
        let machException = crash.exceptionType.flatMap { machExceptionNames[$0.int32Value] }
        let reason = crash.exceptionReason
        let summary = [machException, signal].compactMap(\.self).joined(separator: " · ")
        return ExceptionReport(
            level: .fatal,
            type: reason?.exceptionName ?? signal ?? machException ?? "Crash",
            // The format string, not the composed message: its arguments can carry values the app was handling.
            value: reason?.formatString ?? crash.terminationReason ?? (summary.isEmpty ? "Crash" : summary),
            mechanism: "metrickit_crash",
            stack: stack(crash.callStackTree),
            details: details(of: crash),
        )
    }

    static func report(_ hang: MXHangDiagnostic) -> ExceptionReport {
        var details = details(of: hang)
        details["hang_seconds"] = seconds(hang.hangDuration)
        return ExceptionReport(
            level: .error,
            type: "App Hang",
            value: "The main thread stopped responding",
            mechanism: "metrickit_hang",
            stack: stack(hang.callStackTree),
            details: details,
        )
    }

    static func report(_ exception: MXCPUExceptionDiagnostic) -> ExceptionReport {
        var details = details(of: exception)
        details["cpu_seconds"] = seconds(exception.totalCPUTime)
        details["sampled_seconds"] = seconds(exception.totalSampledTime)
        return ExceptionReport(
            level: .error,
            type: "CPU Exception",
            value: "The app went over the system's CPU time limit",
            mechanism: "metrickit_cpu_exception",
            stack: stack(exception.callStackTree),
            details: details,
        )
    }

    static func report(_ launch: MXAppLaunchDiagnostic) -> ExceptionReport {
        var details = details(of: launch)
        details["launch_seconds"] = seconds(launch.launchDuration)
        return ExceptionReport(
            level: .error,
            type: "Slow Launch",
            value: "The app took too long to launch",
            mechanism: "metrickit_launch",
            stack: stack(launch.callStackTree),
            details: details,
        )
    }

    static func report(_ exception: MXDiskWriteExceptionDiagnostic) -> ExceptionReport {
        var details = details(of: exception)
        details["written_megabytes"] = String(format: "%.0f", exception.totalWritesCaused.converted(to: .megabytes).value)
        return ExceptionReport(
            level: .error,
            type: "Disk Write Exception",
            value: "The app went over the system's disk write limit",
            mechanism: "metrickit_disk_write_exception",
            stack: stack(exception.callStackTree),
            details: details,
        )
    }

    private static func stack(_ tree: MXCallStackTree) -> ExceptionReport.Stack {
        (try? ExceptionReport.Stack(callStackTree: tree.jsonRepresentation(), appBinary: appBinary)) ?? ExceptionReport.Stack()
    }

    /// The build that crashed can be older than the one sending it.
    private static func details(of diagnostic: MXDiagnostic) -> [String: String] {
        [
            "diagnostic_app_version": diagnostic.applicationVersion,
            "diagnostic_build": diagnostic.metaData.applicationBuildVersion,
            "diagnostic_os_version": diagnostic.metaData.osVersion,
            "diagnostic_device": diagnostic.metaData.deviceType,
        ]
    }

    private static func seconds(_ measurement: Measurement<UnitDuration>) -> String {
        String(format: "%.2f", measurement.converted(to: .seconds).value)
    }

    // MARK: Functions

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            let reports = (payload.crashDiagnostics ?? []).map(Self.report)
                + (payload.hangDiagnostics ?? []).map(Self.report)
                + (payload.cpuExceptionDiagnostics ?? []).map(Self.report)
                + (payload.appLaunchDiagnostics ?? []).map(Self.report)
                + (payload.diskWriteExceptionDiagnostics ?? []).map(Self.report)
            for report in reports {
                send(report, payload.timeStampEnd)
            }
        }
    }
}
