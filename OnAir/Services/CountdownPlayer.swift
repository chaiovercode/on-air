import AVFoundation
import Foundation

final class CountdownPlayer: ObservableObject {

    @Published private(set) var isPlaying = false

    private var player: AVAudioPlayer?
    private var playTimer: Timer?

    var soundDuration: TimeInterval {
        player?.duration ?? 0
    }

    @discardableResult
    func loadSound(customPath: String?, volume: Float) -> Bool {
        player?.stop()
        player = nil

        if let customPath,
           let url = resolveCustomSoundURL(customPath),
           let p = try? AVAudioPlayer(contentsOf: url) {
            p.volume = volume
            p.prepareToPlay()
            player = p
            return true
        }

        // Try .wav first (our bundled default), then .aiff
        for ext in ["wav", "aiff"] {
            if let url = Bundle.main.url(forResource: "countdown", withExtension: ext),
               let p = try? AVAudioPlayer(contentsOf: url) {
                p.volume = volume
                p.prepareToPlay()
                player = p
                return true
            }
        }

        return false
    }

    func schedulePlayback(meetingStartDate: Date, leadTimeSeconds: Int) {
        guard let player else { return }

        let soundLen = player.duration
        let leadTime = TimeInterval(leadTimeSeconds)
        let now = Date()
        let timeUntilMeeting = meetingStartDate.timeIntervalSince(now)

        guard timeUntilMeeting > 0 else { return }

        let startOffset: TimeInterval

        if soundLen <= leadTime {
            startOffset = timeUntilMeeting - soundLen
        } else {
            startOffset = timeUntilMeeting - leadTime
            player.currentTime = soundLen - leadTime
        }

        if startOffset <= 0 {
            let elapsed = -startOffset
            let effectiveStart: TimeInterval
            if soundLen > leadTime {
                effectiveStart = (soundLen - leadTime) + elapsed
            } else {
                effectiveStart = elapsed
            }
            guard effectiveStart < soundLen else { return }
            player.currentTime = effectiveStart
            play()
        } else {
            playTimer?.invalidate()
            playTimer = Timer.scheduledTimer(withTimeInterval: startOffset, repeats: false) { [weak self] _ in
                self?.play()
            }
        }
    }

    func stop() {
        playTimer?.invalidate()
        playTimer = nil
        player?.stop()
        isPlaying = false
    }

    func updateVolume(_ volume: Float) {
        player?.volume = volume
    }

    func playTestSound(customPath: String?, volume: Float) {
        loadSound(customPath: customPath, volume: volume)
        player?.currentTime = 0
        play()
        let previewDuration = min(soundDuration, 5.0)
        DispatchQueue.main.asyncAfter(deadline: .now() + previewDuration) { [weak self] in
            self?.stop()
        }
    }

    private func play() {
        player?.play()
        isPlaying = true
    }

    private func resolveCustomSoundURL(_ path: String) -> URL? {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        let supportedExtensions = ["mp3", "wav", "m4a", "aiff"]
        guard supportedExtensions.contains(url.pathExtension.lowercased()),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }
}
