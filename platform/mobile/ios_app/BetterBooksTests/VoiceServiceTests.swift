import XCTest
@testable import BetterBooks

@MainActor
final class VoiceServiceTests: XCTestCase {

    var voiceService: VoiceService!

    override func setUp() async throws {
        voiceService = VoiceService()
    }

    override func tearDown() async throws {
        voiceService.reset()
        voiceService = nil
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertEqual(voiceService.state, .idle)
        XCTAssertEqual(voiceService.recordingTime, 0)
        XCTAssertNil(voiceService.error)
    }

    // MARK: - State Transitions Tests

    func testResetResetsState() {
        voiceService.recordingTime = 10.0
        voiceService.error = "Test error"

        voiceService.reset()

        XCTAssertEqual(voiceService.state, .idle)
        XCTAssertEqual(voiceService.recordingTime, 0)
        XCTAssertNil(voiceService.error)
    }

    func testCancelRecordingResetsState() {
        voiceService.cancelRecording()

        XCTAssertEqual(voiceService.state, .idle)
        XCTAssertEqual(voiceService.recordingTime, 0)
    }

    // MARK: - Recording Time Format Tests

    func testFormatRecordingTimeZero() {
        voiceService.recordingTime = 0
        XCTAssertEqual(voiceService.formatRecordingTime(), "0:00.0")
    }

    func testFormatRecordingTimeSeconds() {
        voiceService.recordingTime = 5.3
        XCTAssertEqual(voiceService.formatRecordingTime(), "0:05.3")
    }

    func testFormatRecordingTimeMinutes() {
        voiceService.recordingTime = 65.7
        XCTAssertEqual(voiceService.formatRecordingTime(), "1:05.7")
    }

    func testFormatRecordingTimeLong() {
        voiceService.recordingTime = 125.9
        XCTAssertEqual(voiceService.formatRecordingTime(), "2:05.9")
    }

    // MARK: - Stop Recording Tests

    func testStopRecordingWhenNotRecording() {
        // Should return nil and not crash when not recording
        let result = voiceService.stopRecording()
        XCTAssertNil(result)
    }
}

// MARK: - VoiceError Tests

final class VoiceErrorTests: XCTestCase {

    func testMicrophonePermissionDeniedDescription() {
        let error = VoiceError.microphonePermissionDenied
        XCTAssertEqual(error.errorDescription, "Microphone access is required for voice chat")
    }

    func testRecordingFailedDescription() {
        let error = VoiceError.recordingFailed
        XCTAssertEqual(error.errorDescription, "Failed to record audio")
    }

    func testInvalidAudioDataDescription() {
        let error = VoiceError.invalidAudioData
        XCTAssertEqual(error.errorDescription, "Invalid audio data")
    }

    func testPlaybackFailedDescription() {
        let error = VoiceError.playbackFailed
        XCTAssertEqual(error.errorDescription, "Failed to play audio")
    }
}
