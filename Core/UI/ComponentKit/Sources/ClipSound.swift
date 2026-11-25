import AVFoundation
import os
import UIKit

/// The app's audio session as clips need it. Muted clips play alongside other audio and never take it over; a clip's
/// sound, once someone turns to it full screen, plays as any video does (through the silent switch, pausing other
/// audio) until the audio is handed back, so what was playing resumes. Handing it back deactivates the session, which
/// stops every player in it, so muting in between is the player's own `isMuted`, and the audio goes back only once no
/// clip is playing (or the app leaves the screen, which pauses them).
public enum ClipSound {

    // MARK: Types

    private nonisolated enum State: Sendable {
        case muted
        case sound
    }

    // MARK: Static Properties

    /// Posted once the session says what was last asked. Deactivating it stops every player in it (`setActive`'s busy
    /// case), so a clip that should be playing starts again here.
    static let didSettle = Notification.Name("ClipSound.didSettle")

    private nonisolated static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "clip-sound")
    private static var wanted: State?
    private static var applied: State?
    /// Applies the newest wish, one at a time and off the main thread, where activating the session can block.
    private static var worker: Task<Void, Never>?
    private static var handBackPending = false
    private static var playing = Set<ObjectIdentifier>()
    private static var backgroundObserver: any NSObjectProtocol?

    // MARK: Static Functions

    public static func takeAudio() {
        handBackPending = false
        want(.sound)
    }

    public static func handBackAudio() {
        guard wanted == .sound else {
            return
        }
        handBackPending = true
        handBackIfIdle()
    }

    /// Before the first clip plays, so even a muted one never stops what else is playing.
    static func prepare() {
        if wanted == nil {
            want(.muted)
        }
        if backgroundObserver == nil {
            backgroundObserver = NotificationCenter.default.addObserver(
                forName: UIScene.didEnterBackgroundNotification,
                object: nil,
                queue: .main,
            ) { _ in
                MainActor.assumeIsolated {
                    playing.removeAll()
                    handBackIfIdle()
                }
            }
        }
    }

    static func playerStarted(_ player: ObjectIdentifier) {
        playing.insert(player)
    }

    static func playerStopped(_ player: ObjectIdentifier) {
        playing.remove(player)
        handBackIfIdle()
    }

    private static func handBackIfIdle() {
        guard handBackPending, playing.isEmpty else {
            return
        }
        handBackPending = false
        want(.muted)
    }

    private static func want(_ state: State) {
        guard wanted != state else {
            return
        }
        wanted = state
        guard worker == nil else {
            return
        }
        worker = Task {
            while let next = wanted, next != applied {
                await apply(next, after: applied)
                applied = next
            }
            worker = nil
            NotificationCenter.default.post(name: didSettle, object: nil)
        }
    }

    @concurrent
    private static func apply(_ state: State, after previous: State?) async {
        let session = AVAudioSession.sharedInstance()
        switch state {
        case .sound:
            do {
                try session.setCategory(.playback, mode: .moviePlayback)
                try session.setActive(true)
            } catch {
                logger.notice("The clip's sound couldn't take the audio: \(String(describing: error), privacy: .public)")
            }

        case .muted:
            if previous == .sound {
                do {
                    try session.setActive(false, options: .notifyOthersOnDeactivation)
                } catch {
                    logger.notice("The clip's sound couldn't hand the audio back: \(String(describing: error), privacy: .public)")
                }
            }
            do {
                try session.setCategory(.ambient)
            } catch {
                logger.notice("Clips couldn't mix with other audio: \(String(describing: error), privacy: .public)")
            }
        }
    }
}
