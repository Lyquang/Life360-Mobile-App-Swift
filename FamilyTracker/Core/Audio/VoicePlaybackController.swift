import AVFoundation
import Combine
import Foundation

@MainActor
final class VoicePlaybackController: ObservableObject {
    @Published private(set) var activeURL: URL?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress = 0.0

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    deinit {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
    }

    func toggle(url: URL) {
        if activeURL == url, let player {
            isPlaying ? player.pause() : player.play()
            isPlaying.toggle()
            return
        }
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        activeURL = url
        isPlaying = true
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600),
                                                      queue: .main) { [weak self, weak item] time in
            guard let item else { return }
            let duration = item.duration.seconds
            let progress = duration.isFinite && duration > 0 ? min(1, time.seconds / duration) : 0
            Task { @MainActor in self?.progress = progress }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.stop() } }
        player.play()
    }

    func stop() {
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        player = nil
        activeURL = nil
        isPlaying = false
        progress = 0
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
