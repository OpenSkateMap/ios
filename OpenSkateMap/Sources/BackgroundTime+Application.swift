import BackgroundTasks
import ContributionsKit
import os
import UIKit

extension BackgroundTime {
    static let application = BackgroundTime { work, expired in
        let task = await ApplicationBackgroundTask { Task { await expired() } }
        await work()
        await task.end()
    } runShown: { title, work, expired in
        let run = await ContinuedRun(title: title, expired: expired)
        await work(run.progress)
        await run.end()
    }
}

// MARK: - ApplicationBackgroundTask

/// Ends its task once, whichever comes first: the work returning or the time running out.
@MainActor
private final class ApplicationBackgroundTask {

    // MARK: Properties

    private var id = UIBackgroundTaskIdentifier.invalid

    // MARK: Lifecycle

    init(expired: @escaping @MainActor () -> Void) {
        // The expiration handler runs on the main thread and must end the task before it returns, or the system kills the app.
        id = UIApplication.shared.beginBackgroundTask(withName: "Contributions outbox") { [weak self] in
            MainActor.assumeIsolated {
                self?.end()
                expired()
            }
        }
    }

    // MARK: Functions

    func end() {
        guard id != .invalid else {
            return
        }
        UIApplication.shared.endBackgroundTask(id)
        id = .invalid
    }
}

// MARK: - ContinuedRun

/// Shown work: the app's usual background time, plus a continued-processing task once the work first reports. While
/// that task runs, the system shows its progress and the work outlives the usual time; when it can't start now
/// (`.fail`), the usual time alone carries the work, as for any other pass.
@MainActor
private final class ContinuedRun {

    // MARK: Static Properties

    /// Matches `BGTaskSchedulerPermittedIdentifiers` (`$(BUNDLE_ID).upload.*`); each run adds its own suffix.
    private static let identifierPrefix = "\(Bundle.main.bundleIdentifier ?? "").upload."

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "outbox")

    private static let progressScale: Int64 = 1000

    // MARK: Computed Properties

    nonisolated var progress: BackgroundProgress {
        BackgroundProgress { [weak self, tracked] completed, total, subtitle in
            tracked.totalUnitCount = Int64(total)
            tracked.completedUnitCount = Int64(completed)
            Task { @MainActor in self?.show(subtitle, at: completed) }
        }
    }

    // MARK: Properties

    /// Its own `Progress`, set from the outbox's actor as it goes; becomes the task's child once the task starts.
    private nonisolated let tracked = Progress(totalUnitCount: 0)
    private let title: String
    private let expired: @Sendable () async -> Void
    private var application: ApplicationBackgroundTask?
    private var phase = Phase.waitingForFirstReport
    private var subtitle = ""
    private var subtitleStep = -1

    // MARK: Lifecycle

    init(title: String, expired: @escaping @Sendable () async -> Void) {
        self.title = title
        self.expired = expired
        application = ApplicationBackgroundTask { [weak self] in
            self?.applicationTimeRanOut()
        }
    }

    // MARK: Functions

    func end() {
        if case .running(let task) = phase {
            task.setTaskCompleted(success: true)
        }
        phase = .done
        application?.end()
        application = nil
    }

    private func show(_ subtitle: String, at step: Int) {
        guard step >= subtitleStep else {
            return
        }
        subtitleStep = step
        self.subtitle = subtitle
        switch phase {
        case .waitingForFirstReport: submit()
        case .running(let task): task.updateTitle(title, subtitle: subtitle)
        case .submitted, .done: break
        }
    }

    private func submit() {
        let identifier = Self.identifierPrefix + UUID().uuidString
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: .main) { [weak self] task in
            MainActor.assumeIsolated {
                guard let task = task as? BGContinuedProcessingTask, let self else {
                    task.setTaskCompleted(success: false)
                    return
                }
                self.started(task)
            }
        }
        guard registered else {
            Self.logger.error("The upload's background task identifier isn't permitted")
            phase = .done
            return
        }
        let request = BGContinuedProcessingTaskRequest(identifier: identifier, title: title, subtitle: subtitle)
        request.strategy = .fail
        do {
            try BGTaskScheduler.shared.submit(request)
            phase = .submitted
        } catch {
            Self.logger.notice("The upload continues without system progress: \(String(describing: error), privacy: .public)")
            phase = .done
        }
    }

    private func started(_ task: BGContinuedProcessingTask) {
        guard case .submitted = phase else {
            task.setTaskCompleted(success: true)
            return
        }
        phase = .running(task)
        task.expirationHandler = { [weak self] in
            Task { @MainActor in self?.continuedTimeRanOut() }
        }
        task.progress.totalUnitCount = Self.progressScale
        task.progress.addChild(tracked, withPendingUnitCount: Self.progressScale)
        task.updateTitle(title, subtitle: subtitle)
    }

    /// The usual time is up; a running continued task keeps the work going, otherwise it stops here.
    private func applicationTimeRanOut() {
        if case .running = phase {
            return
        }
        Task { [expired] in await expired() }
    }

    /// The person cancelled it from the system's progress, or the system needs the resources back.
    private func continuedTimeRanOut() {
        guard case .running(let task) = phase else {
            return
        }
        phase = .done
        Task { [expired] in await expired() }
        task.setTaskCompleted(success: false)
        application?.end()
        application = nil
    }
}

// MARK: ContinuedRun.Phase

extension ContinuedRun {
    private enum Phase {
        case waitingForFirstReport
        case submitted
        case running(BGContinuedProcessingTask)
        case done
    }
}
