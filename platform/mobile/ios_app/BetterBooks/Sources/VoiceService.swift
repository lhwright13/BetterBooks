import Foundation
import AVFoundation
import Combine

/// Voice recording and playback service for voice chat
@MainActor
class VoiceService: NSObject, ObservableObject {
    enum RecordingState {
        case idle
        case recording
        case processing
        case playingResponse
    }

    @Published var state: RecordingState = .idle
    @Published var recordingTime: TimeInterval = 0
    @Published var error: String?

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingTimer: Timer?
    private var recordingURL: URL?

    private let maxRecordingDuration: TimeInterval = 30 // 30 seconds max

    override init() {
        super.init()
    }

    // MARK: - Recording

    func startRecording() async throws {
        // Request microphone permission
        let hasPermission = await requestMicrophonePermission()
        guard hasPermission else {
            throw VoiceError.microphonePermissionDenied
        }

        // Setup audio session for recording
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        // Create recording URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordingURL = documentsPath.appendingPathComponent("voice_recording.wav")

        // Recording settings for WAV format
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: recordingURL!, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record(forDuration: maxRecordingDuration)

        state = .recording
        recordingTime = 0
        error = nil

        // Start timer for UI updates
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingTime += 0.1
            }
        }
    }

    func stopRecording() -> Data? {
        recordingTimer?.invalidate()
        recordingTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil

        state = .processing

        // Read recorded audio data
        guard let url = recordingURL,
              let audioData = try? Data(contentsOf: url) else {
            state = .idle
            error = "Failed to read recording"
            return nil
        }

        // Clean up recording file
        try? FileManager.default.removeItem(at: url)
        recordingURL = nil

        return audioData
    }

    func cancelRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
            recordingURL = nil
        }

        state = .idle
        recordingTime = 0
    }

    // MARK: - Playback

    func playAudioResponse(_ base64Audio: String) async throws {
        guard let audioData = Data(base64Encoded: base64Audio) else {
            throw VoiceError.invalidAudioData
        }

        try await playAudioData(audioData)
    }

    func playAudioData(_ audioData: Data) async throws {
        state = .playingResponse

        // Setup audio session for playback
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)

        audioPlayer = try AVAudioPlayer(data: audioData)
        audioPlayer?.delegate = self
        audioPlayer?.play()

        // Wait for playback to complete
        await withCheckedContinuation { continuation in
            self.playbackCompletion = {
                continuation.resume()
            }
        }

        state = .idle
    }

    private var playbackCompletion: (() -> Void)?

    // MARK: - Permissions

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Utilities

    func formatRecordingTime() -> String {
        let minutes = Int(recordingTime) / 60
        let seconds = Int(recordingTime) % 60
        let tenths = Int((recordingTime.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%d:%02d.%d", minutes, seconds, tenths)
    }

    func reset() {
        cancelRecording()
        audioPlayer?.stop()
        audioPlayer = nil
        state = .idle
        error = nil
    }
}

// MARK: - AVAudioRecorderDelegate

extension VoiceService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                error = "Recording failed"
                state = .idle
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension VoiceService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            playbackCompletion?()
            playbackCompletion = nil
        }
    }
}

// MARK: - Errors

enum VoiceError: Error, LocalizedError {
    case microphonePermissionDenied
    case recordingFailed
    case invalidAudioData
    case playbackFailed

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required for voice chat"
        case .recordingFailed:
            return "Failed to record audio"
        case .invalidAudioData:
            return "Invalid audio data"
        case .playbackFailed:
            return "Failed to play audio"
        }
    }
}
