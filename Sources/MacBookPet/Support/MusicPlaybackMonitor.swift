import AppKit

@MainActor
final class MusicPlaybackMonitor {
    private static let musicBundleIdentifier = "com.apple.Music"

    var onPlaybackChanged: ((Bool) -> Void)?

    private var timer: Timer?
    private var isCheckInFlight = false
    private var lastPublishedState: Bool?

    func start() {
        stop()
        checkPlaybackState()

        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPlaybackState()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkPlaybackState() {
        guard !isCheckInFlight else { return }

        let isMusicRunning = !NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.musicBundleIdentifier
        ).isEmpty

        guard isMusicRunning else {
            publish(false)
            return
        }

        isCheckInFlight = true
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let isPlaying = Self.queryMusicPlaybackState()

            DispatchQueue.main.async {
                guard let self else { return }
                self.isCheckInFlight = false

                if let isPlaying {
                    self.publish(isPlaying)
                }
            }
        }
    }

    private func publish(_ isPlaying: Bool) {
        guard lastPublishedState != isPlaying else { return }
        lastPublishedState = isPlaying
        onPlaybackChanged?(isPlaying)
    }

    private nonisolated static func queryMusicPlaybackState() -> Bool? {
        let source = """
        tell application id "com.apple.Music"
            if player state is playing then
                return "playing"
            end if
            return "notPlaying"
        end tell
        """

        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)

        guard error == nil else { return nil }
        return result.stringValue == "playing"
    }

    deinit {
        timer?.invalidate()
    }
}
