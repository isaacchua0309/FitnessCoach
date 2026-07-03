//
//  CoachSpeechTests.swift
//  Fitness CoachTests
//
//  Forma — Unit tests for Coach speech-to-text error copy.
//

import XCTest
@testable import Fitness_Coach

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
}
