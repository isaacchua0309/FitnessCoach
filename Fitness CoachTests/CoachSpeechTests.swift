//
//  CoachSpeechTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for Coach speech-to-text error copy and transcript merging.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class CoachSpeechTests: XCTestCase {

    func testSpeechErrorMessagesAreUserFriendly() {
        XCTAssertTrue(
            CoachResponseBuilder.speechError(.microphonePermissionDenied)
                .localizedCaseInsensitiveContains("microphone")
        )
        XCTAssertTrue(
            CoachResponseBuilder.speechError(.speechRecognitionPermissionDenied)
                .localizedCaseInsensitiveContains("speech recognition")
        )
        XCTAssertFalse(CoachResponseBuilder.speechError(.recognizerUnavailable).isEmpty)
        XCTAssertFalse(CoachResponseBuilder.speechError(.audioSessionFailed).isEmpty)
        XCTAssertFalse(CoachResponseBuilder.speechError(.recognitionFailed).isEmpty)
    }

    func testCombinedTranscriptPreservesManualPrefix() {
        XCTAssertEqual(
            CoachSpeechRecognizerService.combinedTranscript(prefix: "Hello", transcript: "world"),
            "Hello world"
        )
    }

    func testCombinedTranscriptDoesNotDuplicatePrefix() {
        XCTAssertEqual(
            CoachSpeechRecognizerService.combinedTranscript(prefix: "Hello", transcript: "Hello world"),
            "Hello world"
        )
    }

    func testCombinedTranscriptReturnsPrefixWhenTranscriptEmpty() {
        XCTAssertEqual(
            CoachSpeechRecognizerService.combinedTranscript(prefix: "Manual note", transcript: "   "),
            "Manual note"
        )
    }

    func testUserEditDuringRecordingStopsSessionWithoutClearingText() async {
        let service = CoachSpeechRecognizerService()
        var text = "typed"

        service.userDidEditInput()

        XCTAssertFalse(service.isRecording)
        XCTAssertFalse(service.isVoiceInputBusy)
        XCTAssertEqual(text, "typed")
    }
}
