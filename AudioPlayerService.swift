import Foundation
import AVFoundation
import Combine

/// Lightweight AVPlayer wrapper for ayah/adhan playback.
final class AudioPlayerService: ObservableObject {
    @Published var isPlaying = false
    @Published var progress: Double = 0
    @Published var duration: Double = 0

    private var player: AVPlayer?
    private var timeObserver: Any?

    func play(url: URL, metadata: String) {
        stop()
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        isPlaying = true

        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 10),
                                                       queue: .main) { [weak self] time in
            guard let self, let duration = self.player?.currentItem?.duration.seconds, duration > 0 else { return }
            self.duration = duration
            self.progress = time.seconds / duration
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func stop() {
        player?.pause()
        if let obs = timeObserver { player?.removeTimeObserver(obs) }
        player = nil
        isPlaying = false
        progress = 0
        duration = 0
    }
}

