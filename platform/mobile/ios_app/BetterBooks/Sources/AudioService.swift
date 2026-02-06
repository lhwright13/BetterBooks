import Foundation
import AVFoundation
import Combine

/// Audio playback service for audiobook streaming
@MainActor
class AudioService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var isLoading = false
    @Published var error: String?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    func play(url: URL) {
        isLoading = true
        error = nil

        // Remove old observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)

        // Observe player status
        playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                switch status {
                case .readyToPlay:
                    self?.isLoading = false
                    self?.duration = playerItem.duration.seconds
                    self?.player?.play()
                    self?.isPlaying = true
                case .failed:
                    self?.isLoading = false
                    self?.error = playerItem.error?.localizedDescription ?? "Failed to load audio"
                default:
                    break
                }
            }
            .store(in: &cancellables)

        // Time observer for progress updates
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func resume() {
        player?.play()
        isPlaying = true
    }

    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player?.seek(to: cmTime)
    }

    func skip(seconds: TimeInterval) {
        let newTime = max(0, min(currentTime + seconds, duration))
        seek(to: newTime)
    }

    func stop() {
        player?.pause()
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0

        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
